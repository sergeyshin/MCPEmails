#!/bin/sh
set -eu

: "${DB_HOST:?}"
: "${DB_USER:?}"
: "${DB_PASSWORD:?}"
: "${DB_NAME:?}"
: "${MCP_URL:?}"
: "${TEST_KEY:?}"
: "${TEST_KEY_HASH:?}"
: "${TEST_KEY_PREFIX:?}"
: "${EXPIRED_KEY:?}"
: "${EXPIRED_KEY_HASH:?}"
: "${EXPIRED_KEY_PREFIX:?}"

export PGPASSWORD="$DB_PASSWORD"

cleanup() {
  psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -qAt     -c "DELETE FROM public.api_keys WHERE key_hash IN ('$TEST_KEY_HASH','$EXPIRED_KEY_HASH');"     >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -qAt <<SQL
INSERT INTO public.api_keys
  (workspace_id, created_by, name, key_prefix, key_hash, scopes, expires_at)
VALUES
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   'two-service-release-test',
   '$TEST_KEY_PREFIX',
   '$TEST_KEY_HASH',
   ARRAY['read:email'],
   now() + interval '1 hour')
ON CONFLICT (key_hash) DO UPDATE
SET deleted_at = NULL,
    expires_at = EXCLUDED.expires_at,
    scopes = EXCLUDED.scopes;

INSERT INTO public.api_keys
  (workspace_id, created_by, name, key_prefix, key_hash, scopes, expires_at)
VALUES
  ('00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   'two-service-expired-test',
   '$EXPIRED_KEY_PREFIX',
   '$EXPIRED_KEY_HASH',
   ARRAY['read:email'],
   now() - interval '1 hour')
ON CONFLICT (key_hash) DO UPDATE
SET deleted_at = NULL,
    expires_at = EXCLUDED.expires_at,
    scopes = EXCLUDED.scopes;
SQL

health=$(curl --max-time 20 -sS -o /tmp/health -w '%{http_code}' "$MCP_URL/health")
test "$health" = "200"
grep -qx "ok" /tmp/health

noauth=$(curl --max-time 20 -sS -o /tmp/noauth -w '%{http_code}'   -H 'Content-Type: application/json'   --data-binary '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'   "$MCP_URL/")
test "$noauth" = "401"

badauth=$(curl --max-time 20 -sS -o /tmp/badauth -w '%{http_code}'   -H 'Authorization: Bearer mcpe_0000000000000000000000000000000000000000000000000000000000000000'   -H 'Content-Type: application/json'   --data-binary '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'   "$MCP_URL/")
test "$badauth" = "401"

expired=$(curl --max-time 20 -sS -o /tmp/expired -w '%{http_code}'   -H "Authorization: Bearer $EXPIRED_KEY"   -H 'Content-Type: application/json'   --data-binary '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'   "$MCP_URL/")
test "$expired" = "401"

curl --max-time 20 --fail-with-body -sS -o /tmp/init   -H "Authorization: Bearer $TEST_KEY"   -H 'Content-Type: application/json'   --data-binary '{"jsonrpc":"2.0","id":4,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"release-test","version":"1"}}}'   "$MCP_URL/"
jq -e '.result.serverInfo.name == "mcpemails" and .result.protocolVersion == "2025-06-18"' /tmp/init >/dev/null

curl --max-time 20 --fail-with-body -sS -o /tmp/tools   -H "Authorization: Bearer $TEST_KEY"   -H 'Content-Type: application/json'   --data-binary '{"jsonrpc":"2.0","id":5,"method":"tools/list","params":{}}'   "$MCP_URL/"
jq -e '.result.tools | map(.name) | index("inbox_list") != null' /tmp/tools >/dev/null
tools_count=$(jq '.result.tools | length' /tmp/tools)

curl --max-time 20 --fail-with-body -sS -o /tmp/inbox   -H "Authorization: Bearer $TEST_KEY"   -H 'Content-Type: application/json'   --data-binary '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"inbox_list","arguments":{}}}'   "$MCP_URL/"
grep -q 'setup_required' /tmp/inbox

write_scope=$(curl --max-time 20 -sS -o /tmp/write -w '%{http_code}'   -H "Authorization: Bearer $TEST_KEY"   -H 'Content-Type: application/json'   --data-binary '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"email_compose","arguments":{"action":"send","to":["nobody@example.invalid"],"subject":"x","body":"x"}}}'   "$MCP_URL/")
test "$write_scope" = "403"

malformed=$(printf '{' | curl --max-time 20 -sS -o /tmp/malformed -w '%{http_code}'   -H "Authorization: Bearer $TEST_KEY"   -H 'Content-Type: application/json'   --data-binary @- "$MCP_URL/")
test "$malformed" = "400"

oversize=$(curl --max-time 20 -sS -o /tmp/oversize -w '%{http_code}'   -H "Authorization: Bearer $TEST_KEY"   -H 'Content-Type: application/json'   -H 'Content-Length: 20000000'   --data-binary '{}' "$MCP_URL/" || true)
test "$oversize" = "413"

options=$(curl --max-time 20 -sS -o /tmp/options -w '%{http_code}'   -X OPTIONS "$MCP_URL/")
test "$options" = "204"

echo "RELEASE_TEST_PASS health=$health noauth=$noauth badauth=$badauth expired=$expired write_scope=$write_scope malformed=$malformed oversize=$oversize options=$options tools=$tools_count"

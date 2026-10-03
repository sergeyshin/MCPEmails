#!/bin/sh
set -eu

: "${PGRST_DB_URI:?PGRST_DB_URI is required}"
: "${PGRST_JWT_SECRET:?PGRST_JWT_SECRET is required}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is required}"

export PGRST_SERVER_HOST=127.0.0.1
export PGRST_SERVER_PORT=3000
export PGRST_DB_SCHEMAS="${PGRST_DB_SCHEMAS:-public}"
export PGRST_DB_ANON_ROLE="${PGRST_DB_ANON_ROLE:-anon}"
export PGRST_DB_USE_LEGACY_GUCS="${PGRST_DB_USE_LEGACY_GUCS:-false}"
export SUPABASE_URL=http://127.0.0.1:3000

postgrest &
PGRST_PID=$!

deno run \
  --cached-only \
  --node-modules-dir=none \
  --lock=/app/deno.lock \
  --frozen \
  --allow-net \
  --allow-env \
  /app/mcp-server/index.ts &
MCP_PID=$!

shutdown() {
  kill "$MCP_PID" "$PGRST_PID" 2>/dev/null || true
  wait "$MCP_PID" 2>/dev/null || true
  wait "$PGRST_PID" 2>/dev/null || true
}
trap shutdown INT TERM EXIT

while kill -0 "$PGRST_PID" 2>/dev/null && kill -0 "$MCP_PID" 2>/dev/null; do
  sleep 1
done

if ! kill -0 "$PGRST_PID" 2>/dev/null; then
  wait "$PGRST_PID" || STATUS=$?
  echo "PostgREST exited unexpectedly" >&2
else
  wait "$MCP_PID" || STATUS=$?
  echo "MCP server exited unexpectedly" >&2
fi

exit "${STATUS:-1}"

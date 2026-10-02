# MCP Emails, self-host server image.
#
# Runs the exact same Deno MCP server that powers mcpemails.com
# (supabase/functions/mcp-server), plus the provisioning CLI. No build step or
# bundler: the server is plain Deno and talks to PostgREST over HTTP.
#
# Build context is the repo root (see docker-compose.yml) so we can copy both
# the server source and the self-host CLI.
FROM denoland/deno:2.9.7

WORKDIR /app
ENV DENO_DIR=/app/.deno

# Server source (unmodified) + provisioning CLI.
COPY supabase/functions/mcp-server/ ./mcp-server/
COPY self-host/cli/ ./cli/
COPY self-host/deno.lock ./deno.lock

# Pre-cache the exact dependency graph recorded by the pinned source revision.
# Keep the cache writable by the non-root runtime user, but forbid runtime
# dependency resolution outside this frozen graph.
RUN mkdir -p "$DENO_DIR" \
    && deno cache --node-modules-dir=none --lock=deno.lock --frozen mcp-server/index.ts ./cli/mcpe.ts \
    && chown -R deno:deno "$DENO_DIR"

# Drop root.
USER deno

EXPOSE 8000

# Deno.serve(handleRequest) binds 0.0.0.0:8000 by default.
CMD ["deno", "run", "--cached-only", "--node-modules-dir=none", "--lock=deno.lock", "--frozen", "--allow-net", "--allow-env", "mcp-server/index.ts"]

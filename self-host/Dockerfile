# MCP Emails, compact Railway self-host image.
# One Railway service runs both the public Deno MCP server and a localhost-only
# PostgREST process. PostgreSQL remains the only separate persistent service.
FROM postgrest/postgrest:v12.2.12 AS postgrest

FROM denoland/deno:2.9.7

WORKDIR /app
ENV DENO_DIR=/app/.deno
ENV SELF_HOSTED=1
ENV USAGE_ENFORCEMENT_DISABLED=true

COPY --from=postgrest /bin/postgrest /usr/local/bin/postgrest
COPY supabase/functions/mcp-server/ ./mcp-server/
COPY self-host/cli/ ./cli/
COPY self-host/deno.lock ./deno.lock
COPY self-host/railway-entrypoint.sh ./railway-entrypoint.sh

RUN mkdir -p "$DENO_DIR" \
    && deno cache --node-modules-dir=none --lock=deno.lock --frozen mcp-server/index.ts ./cli/mcpe.ts \
    && chown -R deno:deno "$DENO_DIR" /app/railway-entrypoint.sh \
    && chmod 0555 /app/railway-entrypoint.sh /usr/local/bin/postgrest

USER deno
EXPOSE 8000
CMD ["/app/railway-entrypoint.sh"]

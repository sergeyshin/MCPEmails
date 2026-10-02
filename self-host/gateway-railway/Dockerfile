FROM nginxinc/nginx-unprivileged:1.27-alpine
ENV NGINX_ENVSUBST_FILTER="^POSTGREST_HOST$"
COPY default.conf.template /etc/nginx/templates/default.conf.template
USER nginx
EXPOSE 8080

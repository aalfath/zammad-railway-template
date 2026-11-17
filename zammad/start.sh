#!/usr/bin/env bash
# Railway start script for Zammad: wait for the databases, install or migrate, create the
# first admin, then run nginx, the Rails server, the websocket server and the background
# workers in this one container. If any of them exits, stop the rest and exit non-zero,
# so Railway restarts the service.
set -euo pipefail
cd /opt/zammad
log() { echo "railway-template: $*"; }

# Railway volumes are owned by root: give the storage volume to the zammad user (uid 1000),
# then run the rest of this script as that user.
if [ "$(id -u)" = "0" ]; then
  mkdir -p /opt/zammad/storage
  rm -rf /opt/zammad/storage/lost+found
  if [ "$(stat -c %u /opt/zammad/storage)" != "1000" ]; then
    log "giving /opt/zammad/storage to uid 1000"
    chown -R 1000:1000 /opt/zammad/storage
  fi
  exec setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/opt/zammad "$0" "$@"
fi

# Fixed settings (override any of them with a service variable).
export PORT="${PORT:-8080}"
export POSTGRESQL_DB_CREATE="${POSTGRESQL_DB_CREATE:-false}"
export ELASTICSEARCH_ENABLED="${ELASTICSEARCH_ENABLED:-true}"
export ELASTICSEARCH_SCHEMA="${ELASTICSEARCH_SCHEMA:-http}"
export ELASTICSEARCH_PORT="${ELASTICSEARCH_PORT:-9200}"
export ELASTICSEARCH_USER="${ELASTICSEARCH_USER:-elastic}"
export ELASTICSEARCH_NAMESPACE="${ELASTICSEARCH_NAMESPACE:-zammad}"
export ZAMMAD_HTTP_TYPE="${ZAMMAD_HTTP_TYPE:-https}"
export ZAMMAD_RAILSSERVER_PORT=3000
export ZAMMAD_WEBSOCKET_PORT=6042
export RAILS_TRUSTED_PROXIES="${RAILS_TRUSTED_PROXIES:-127.0.0.1,::1}"
export NGINX_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-50M}"

for v in POSTGRESQL_HOST POSTGRESQL_USER POSTGRESQL_PASS POSTGRESQL_DB REDIS_URL; do
  if [ -z "${!v:-}" ]; then log "$v is empty; check the service variables" >&2; exit 1; fi
done

# nginx: Zammad's own site config, adapted to Railway. Railway's edge terminates TLS and
# sends X-Forwarded-Proto and X-Real-IP; nginx is the only way in, so trust them.
sed -e "s#listen 80;#listen ${PORT};#" \
    -e "s#listen \[::\]:80;#listen [::]:${PORT};#" \
    -e "s#server_name .*#server_name _;#" \
    -e "s#client_max_body_size .*#client_max_body_size ${NGINX_CLIENT_MAX_BODY_SIZE};#" \
    -e 's#proxy_set_header X-Forwarded-Proto .*;#proxy_set_header X-Forwarded-Proto $railway_proto;#' \
    -e 's#access_log .*;#access_log off;#' \
    -e 's#error_log .*;#error_log stderr warn;#' \
    -e 's#server_tokens off;#server_tokens off;\n  set_real_ip_from 0.0.0.0/0;\n  set_real_ip_from ::/0;\n  real_ip_header X-Real-IP;#' \
    contrib/nginx/zammad.conf > /tmp/zammad-site.conf
{
  echo 'map $http_x_forwarded_proto $railway_proto { default $http_x_forwarded_proto; "" $scheme; }'
  cat /tmp/zammad-site.conf
} > /etc/nginx/sites-enabled/default
nginx -t -q

# Wait for PostgreSQL and Elasticsearch (Railway starts all services at once).
until pg_isready -q -h "$POSTGRESQL_HOST" -p "${POSTGRESQL_PORT:-5432}"; do
  log "waiting for PostgreSQL at $POSTGRESQL_HOST"; sleep 3
done
if [ "$ELASTICSEARCH_ENABLED" = "true" ]; then
  : "${ELASTICSEARCH_HOST:?ELASTICSEARCH_HOST is empty}"
  ES_URL="${ELASTICSEARCH_SCHEMA}://${ELASTICSEARCH_HOST}:${ELASTICSEARCH_PORT}"
  case "$ELASTICSEARCH_HOST" in *:*) ES_URL="${ELASTICSEARCH_SCHEMA}://[${ELASTICSEARCH_HOST}]:${ELASTICSEARCH_PORT}";; esac
  for i in $(seq 1 120); do
    if curl -fsS -o /dev/null -u "${ELASTICSEARCH_USER}:${ELASTICSEARCH_PASS:-}" "$ES_URL/_cluster/health?wait_for_status=yellow&timeout=5s"; then
      break
    fi
    log "waiting for Elasticsearch at $ELASTICSEARCH_HOST"; sleep 5
  done
fi

# Zammad's own init: creates the schema and seeds on the first start, runs migrations and
# the translation sync on every later start, points Zammad at Elasticsearch and builds
# the search index when it is missing.
log "running zammad-init (the first start takes a few minutes)"
/opt/zammad/bin/docker-entrypoint zammad-init

# URL settings and, on the first start only, the admin account.
bundle exec rails r /opt/railway/setup.rb

pids=()
bundle exec puma -b tcp://127.0.0.1:${ZAMMAD_RAILSSERVER_PORT} -e production & pids+=($!)
bundle exec script/websocket-server.rb -b 127.0.0.1 -p ${ZAMMAD_WEBSOCKET_PORT} start & pids+=($!)
bundle exec script/background-worker.rb start & pids+=($!)

# Open the public port only once Rails answers, so a passing health check means Zammad works.
until curl -fsS -o /dev/null "http://127.0.0.1:${ZAMMAD_RAILSSERVER_PORT}/api/v1/signshow"; do
  kill -0 "${pids[0]}" 2>/dev/null || { log "puma exited during start" >&2; exit 1; }
  sleep 2
done
log "Zammad is ready; nginx listens on port $PORT"
nginx -g 'daemon off;' & pids+=($!)

trap 'kill -TERM "${pids[@]}" 2>/dev/null; wait; exit 0' TERM INT
set +e
wait -n "${pids[@]}"
status=$?
log "a Zammad process exited (status $status); stopping the others" >&2
kill -TERM "${pids[@]}" 2>/dev/null
wait
[ "$status" -eq 0 ] && status=1
exit "$status"

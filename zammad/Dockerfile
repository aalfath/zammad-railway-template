# Zammad for the Railway template: one service runs nginx (public, on $PORT), the Rails
# server, the websocket server and the background workers. start.sh supervises them.
# Official image, pinned by version and digest (7.2.3 build 0011, the "stable" tag on 2026-11-17).
FROM ghcr.io/zammad/zammad:7.2.3-0011@sha256:e34e8adcb9d84dff448edebef54d5b97069db6c6438aa9a98348189123137e72

USER root
# nginx's "worker_processes auto" starts one worker per host CPU (dozens on Railway).
# Log to stderr directly: after start.sh drops from root, /dev/stdout can't be reopened.
RUN sed -i -e 's/^worker_processes auto;/worker_processes 2;/' -e '/^worker_cpu_affinity/d' \
      -e 's#^error_log /dev/stdout;#error_log stderr;#' -e 's#access_log /dev/stdout;#access_log off;#' /etc/nginx/nginx.conf
COPY --chmod=0755 start.sh /opt/railway/start.sh
COPY --chmod=0644 setup.rb /opt/railway/setup.rb
# Stays root only so start.sh can hand the Railway volume (root-owned) to the zammad
# user; start.sh then drops to uid 1000 before running anything else.

ENTRYPOINT ["/opt/railway/start.sh"]

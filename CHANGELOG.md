# Changelog

## 7.2.3 (2026-11-17)

First release of the template.

- Zammad 7.2.3 (`ghcr.io/zammad/zammad:7.2.3-0011@sha256:e34e8adcb9d84dff448edebef54d5b97069db6c6438aa9a98348189123137e72`) in one service: nginx, Rails, websocket server and background workers, after Zammad's own `zammad-init` (install or migrate).
- First admin created by Zammad's auto wizard from `ZAMMAD_ADMIN_EMAIL` and a generated `ZAMMAD_ADMIN_PASSWORD`; the setup page is never public.
- Elasticsearch 9.5.6 (`elastic/elasticsearch@sha256:79b4f1de4c15e6eca824723086a51e5934406d614d410cc11be77748cafac537`): single node, security on, private network only, data on a volume.
- Railway PostgreSQL and Redis, both with volumes.

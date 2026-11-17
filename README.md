[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/zammad-1?utm_medium=integration&utm_source=button&utm_campaign=zammad)

# Zammad on Railway

A one-click [Railway](https://railway.com) template for [Zammad](https://zammad.org), the open-source helpdesk and ticketing system, with Elasticsearch search, PostgreSQL and Redis.

| Service | Source | Image (pinned by version and digest) | Volume |
|---|---|---|---|
| Zammad (public) | `zammad/` | `ghcr.io/zammad/zammad:7.2.3-0011@sha256:e34e8adcb9d84dff448edebef54d5b97069db6c6438aa9a98348189123137e72` | `/opt/zammad/storage` |
| Elasticsearch (private) | `elasticsearch/` | `elastic/elasticsearch:9.5.6@sha256:79b4f1de4c15e6eca824723086a51e5934406d614d410cc11be77748cafac537` | `/usr/share/elasticsearch/data` |
| Postgres (private) | Railway's PostgreSQL | Railway's image | Railway's volume |
| Redis (private) | Railway's Redis | Railway's image | Railway's volume |

Zammad and Elasticsearch build from this repo, so Railway tells everyone who deployed the template when a new version lands on `main`.

## What you get

- Zammad 7.2.3 on a public HTTPS domain. One service runs all of Zammad's processes: nginx on `PORT`, the Rails server, the websocket server and the background workers. `zammad/start.sh` supervises them and restarts the service if one stops.
- An admin account created on the first start from the email you enter and a generated password, through Zammad's own auto wizard. The setup page is never open to whoever finds the URL first.
- Full-text search: a single-node Elasticsearch 9.5.6 with security on and a generated password, reachable only on Railway's private network. Zammad builds its search index on the first start and rebuilds it if it's ever missing.
- Tickets, users, settings and attachments live in PostgreSQL (Zammad's default "Database" storage). All four services keep their data on volumes, so it survives redeploys and restarts.
- Every start runs Zammad's database migrations and translation sync before the site opens, so applying an update is the whole upgrade.
- Health checks: Zammad `/api/v1/signshow` (it answers only once Rails is up), Elasticsearch `/_cluster/health` (the only call allowed without a login).

## After deploying

1. Wait for the first start (3 to 6 minutes): it creates the database and the search index.
2. Open the Zammad service's domain and log in with the email you entered and the `ZAMMAD_ADMIN_PASSWORD` value from the Zammad service's Variables tab. Change the password under Avatar → Profile → Password; the variable is only read on the first start.
3. Set your organization name and logo under Settings → Branding.
4. Connect a mailbox under Settings → Channels → Email. Receiving over IMAP or POP3 works on every Railway plan. Zammad sends mail over SMTP, which Railway allows only on the Pro plan and above ([Railway docs](https://docs.railway.com/networking/outbound-networking)).
5. Adding a custom domain: add it to the Zammad service, then set `ZAMMAD_FQDN` to it (Zammad uses it in email links).

## Variables

| Service | Variable | Default | Notes |
|---|---|---|---|
| Zammad | `ZAMMAD_ADMIN_EMAIL` | (you enter it) | Login and email of the first admin. Read on the first start only. |
| Zammad | `ZAMMAD_ADMIN_PASSWORD` | generated | Password of the first admin. Read on the first start only. |
| Zammad | `ZAMMAD_FQDN` | `${{RAILWAY_PUBLIC_DOMAIN}}` | The host name Zammad puts in links. Set on every start. |
| Zammad | `POSTGRESQL_*`, `REDIS_URL` | references to Postgres and Redis | |
| Zammad | `ELASTICSEARCH_HOST`, `ELASTICSEARCH_PASS` | references to Elasticsearch | |
| Zammad | `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `900` | The first start takes several minutes. |
| Zammad | `PORT` | `8080` | |
| Elasticsearch | `ELASTIC_PASSWORD` | generated | Password of the `elastic` user that Zammad logs in as. Stored on the first start. |
| Elasticsearch | `ES_JAVA_OPTS` | `-Xms1g -Xmx1g` | Java heap. Keep it at about half the memory the service may use. |
| Elasticsearch | `PORT` | `9200` | Private network only. |

Fixed settings (`ZAMMAD_HTTP_TYPE=https`, `POSTGRESQL_DB_CREATE=false`, the Elasticsearch user and namespace, the 50 MB upload limit) have defaults in `zammad/start.sh`; set a variable with the same name to override one. Zammad's other [environment variables](https://docs.zammad.org/en/latest/appendix/environment-variables.html), such as `ZAMMAD_WEB_CONCURRENCY` or `S3_URL`, also work.

## Updates

Version bumps land on `main` with an entry in [CHANGELOG.md](CHANGELOG.md), breaking changes first. Railway then shows an "update available" notice in your project, and you choose when to apply it. Zammad migrates its database on the next start. Back up first (Postgres service → Backups) before a major version, and read [Zammad's release notes](https://zammad.com/en/releases).

## Local test

The two Dockerfiles build and run with plain Docker. Give the Zammad container the same variables as above (Postgres, Redis and Elasticsearch host names and passwords, `ZAMMAD_ADMIN_EMAIL`, `ZAMMAD_ADMIN_PASSWORD`) and publish port 8080.

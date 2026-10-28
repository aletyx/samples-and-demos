# Requests

The history of requests that shaped datyx, newest first.

## 2026-10-28: data sources, and OpenID Connect with Google

Asked: the first entity, data sources, which users add and remove:
databases, S3 or filesystem for now, each with its access details; OIDC
authentication on the API, the dashboard and HealthHub, with the user's
identity propagated through, from HealthHub to the datyx API seamlessly;
Google sign-in set up, with `datyx` and `healthhub` as the Google ids.

Changed: the `DataSource` entity and `/api/datasources` (list, get, add,
remove; [data-sources.md](data-sources.md)), counted in `/api/status`;
Quarkus OIDC as a bearer-token service with Google as the issuer,
`/api/auth/config` and `/api/me`, `CurrentUser`, and
`AuthConfigSourceFactory`, which turns authentication on when
`OIDC_CLIENT_ID` is set and accepts `OIDC_EXTRA_AUDIENCES` (HealthHub's
client) too ([auth.md](auth.md)); the settings in `.env.example`,
`scripts/env.sh`, `scripts/api.sh` and `compose.yaml`; the tests point
OpenMetadata at a closed port; `DataSourceResourceTest`, `AuthOffTest`,
`AuthOnTest` (the OIDC test server as the issuer). The dashboard and
HealthHub changed in their own folders.

## 2026-10-28: API only; the dashboard in its own folder

Asked: create `datyx-dashboard`, a Flutter app like the other demos',
accessing the datyx API; the `datyx` module becomes API only, the
dashboard a separate app that invokes it.

Changed: `datyx-dash/` moved to `../datyx-dashboard/datyx_dashboard/`,
with its own devbox, process-compose, Docker Compose, scripts, id and
version files and specs ([../../datyx-dashboard/specs/](../../datyx-dashboard/specs/)).
Here: the `5-dash` process, the `dash` compose service, `scripts/dash.sh`,
`scripts/make.sh`, `docker/dash.Dockerfile`, `docker/nginx.conf`, the web
targets of `build.sh` and the Makefile, Flutter in `devbox.json`, and
`FLUTTER_WEB_PORT`, `DATYX_DASH_PORT` and `WEB_MODE` are gone; the health
monitor starts after the API and checks API, Postgres, OpenMetadata and
Search; the API's port is published by `compose.yaml` so the dashboard's
container reaches it; README, CLAUDE.md (data and logic here, views in the
dashboard's folder), AGENTS.md and these specs. The repository's
`start-all.sh` waits for datyx on the API's `/api/health`, since it has
no web port.

## 2026-10-28: the dashboard, datyx-dash

Asked: a separate module, `datyx-dash`, a Flutter dashboard (like every
demo's app) that invokes the API; from now on, data and logic go in the
API and views in the dashboard, recorded in the project's CLAUDE.md.

Changed: the Quarkus project moved into `datyx-api/`; `datyx-dash/`, a
Flutter web app with status cards, a hello call, the greetings on record
and a panel of every API call, served under `/app/` on 9906 by a small
Dart web server (release) or Flutter's dev server (debug), both proxying
`/api/` to the API; the API gained `GET /api/status` (database,
OpenMetadata, greetings count) and `GET`/`POST /api/greetings` on the
`Greeting` entity, with an OpenMetadata REST client; `scripts/api.sh`
(was `app.sh`, `API_MODE`), `scripts/dash.sh`, `scripts/make.sh`,
`build.sh` with the web targets, the `5-dash` process, the `api` and
`dash` compose services with their Dockerfiles and nginx; `DATYX_PORT`
became `DATYX_API_PORT`, `DATYX_DASH_PORT` added; Flutter in devbox; the
module convention in CLAUDE.md; README and specs.

## 2026-10-28: start datyx

Asked: a new `datyx` folder for the system, following the demos' patterns
(devbox, process-compose, Docker Compose, the id and version files), with
group and artifact id both `datyx`; a Quarkus app on GraalVM, a PostgreSQL
database and an OpenMetadata server, on port 9900 for the app and 99xx for
the rest; start it up. Then: keep the app a simple hello-world REST API, no
pages, with the usual components (health, Hibernate ORM with Panache).

Changed: the folder, as a git repository, with `devbox.json` (GraalVM CE,
Maven), `process-compose.yaml`, `compose.yaml`, the scripts, the
Dockerfiles, PostgreSQL's init script, the Quarkus project (`GET
/api/hello`, the `Greeting` entity, health, OpenAPI, tests), the Makefile,
the id and version files, README, AGENTS.md, CLAUDE.md and these specs.

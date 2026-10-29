# Requests

The history of requests that shaped the datyx dashboard, newest first.
Its earlier history, as the `datyx-dash` module inside `datyx/`, is in
[../../datyx/specs/requests.md](../../datyx/specs/requests.md).

## 2026-10-29: the dev containers by demo group

Asked: separate the dev containers, images and Codespaces configurations
by demo group.

Changed: the dashboard now runs in a codespace, in the datyx group's dev
container, **datyx demos** (`.devcontainer/datyx/devcontainer.json` at
the repository root), on the group's image
`docker.io/aletyxcode/samples-and-demos-datyx` (`bash
image/build-image.sh datyx`), which carries the API's GraalVM and the
dashboard's release web build and starts it with the API, HealthHub and
the index page. There was no per-demo dev container for it to replace;
the per-demo ones of the other folders were removed. The known
limitation saying it had no codespace is gone from
[dev-environment.md](dev-environment.md).

## 2026-10-28: data sources, and signing in with Google

Asked: let users add or remove data sources (databases, S3, filesystem,
each with its access details), the first entity of datyx; OIDC
authentication on the API, the dashboard and HealthHub, with the user's
identity propagated through; Google sign-in.

Changed: the data sources card and the add dialog, the Sign-in and
Records status cards, the account corner with Google's sign-in button
(`google_sign_in`, `google_sign_in_web`), `AuthController` reading the
client id from the API's `GET /api/auth/config`, the ID token as a bearer
on every call with one silent retry after a 401, the API client's new
calls, and the tests. No setting here: the client id lives with the API.

## 2026-10-28: datyx-dashboard, a folder of its own

Asked: create `datyx-dashboard`, a Flutter app like the other demos',
accessing the datyx API; the `datyx` module becomes API only, and the
dashboard a separate app that invokes it.

Changed: `datyx/datyx-dash/` moved here as `datyx_dashboard/` (package
`datyx_dashboard`), unchanged but for its name and its web server's
settings (`FLUTTER_WEB_PORT`, `DATYX_BIND_HOST`, `DATYX_API_URL`); this
folder got the demos' layout: `devbox.json` (Flutter, with the demos'
lock), `process-compose.yaml` (the dashboard and the health monitor, no
API), `compose.yaml` (nginx with the API's address as a template
variable, the host's 9900 by default), `scripts/` (`flutter-web.sh`,
`build.sh`, `make.sh`, `health-check.sh` with Dash, API and Proxy,
`env.sh`, `version.sh`), the Makefile, the id and version files
(`datyx:datyx-dashboard`, `0.1`), README, AGENTS.md, CLAUDE.md and these
specs. The port stays 9906. The repository's `start-all.sh` learned to
wait for a demo without a web app on its API's `/api/health`, the index
page got a card for the dashboard and the datyx card points at the API,
and the README lists both.

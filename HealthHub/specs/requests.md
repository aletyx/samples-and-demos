# Requests

The requests that shaped HealthHub, oldest first, each with what changed.
The feature files hold the current specification; see the
[index](README.md).

## 2026-10-28

1. **Create a new demo, HealthHub, following the same pattern as the
   others; this one needs a database (PostgreSQL). Copy the structure
   (version and artifact identification, devbox, process-compose, Docker
   Compose, dev container, ...), but for now a single hello world on the
   UI is fine.** Added `HealthHub/`, built like PokerFace: a Flutter app
   (`healthhub_app`, web, Android, iOS and Linux) and a Dart API
   (`healthhub_api`), devbox, process-compose and the health monitor, the
   Makefile and the version files (`0.1`, `aityx:healthhub`; the group
   became `datyx` the same day, see below), Docker
   Compose, and the dev container in `.devcontainer/HealthHub/`, on ports
   8900 (app), 8901 (API) and 8902 (PostgreSQL), moved the same day to
   9800 to 9802 (next request); see [Development
   environment](dev-environment.md). The database is the `postgres`
   service of `compose.yaml`, which `devbox services up` starts with
   `docker compose up postgres` as datyx does, and whose first start
   makes the `healthhub` database and user; the API makes a `greetings`
   table and writes "Hello, world" in it once ([Database](database.md)).
   `GET /api/hello` reads the greeting with PostgreSQL's version, and
   `GET /api/health` reports whether the database answers and whether the
   aityx key is set ([API](api.md)). The app has one screen: the
   greeting, where it was read from, three chips for the API, the
   database and the key, and a refresh button ([Welcome](welcome.md)), in
   the aityx [theme](theme.md). Nothing calls aityx yet. The repository's
   README, index page and all-demos dev container list it; the dev
   containers gain Docker (the `docker-in-docker` feature) for the
   database.
2. **Make HealthHub use the 98xx port prefix, for all components, with
   no clashes with the others.** The app is on 9800, the API on 9801 and
   PostgreSQL on 9802 (they were 8900 to 8902, the range of the other
   demos' apps), in every default, script, Dockerfile, compose file, dev
   container, the index page and the READMEs; the 98xx range was unused
   (the other demos have 88xx and 89xx, datyx 99xx). See [Development
   environment](dev-environment.md).
3. **Make sure every group.id.txt is correct.** HealthHub's group ID is
   `datyx`, not `aityx`: the demos start and stop in two groups, aityx
   (Mortgage Hub, Contact Hub, PokerFace, RoboRules and Cellfie) and
   datyx (the datyx API and dashboard, and HealthHub), and the group ID
   names the group. The coordinates are `datyx:healthhub`.

## 2026-10-28, later

1. **OIDC authentication on the API, the dashboard and the app, with the
   user's identity propagated through, from HealthHub to the datyx API
   seamlessly; Google sign-in, with `healthhub` as the Google ids.**
   The API verifies Google ID tokens (`openid_client`) when
   `OIDC_CLIENT_ID` is set, answers `/api/auth/config` and `/api/me`,
   addresses `/api/hello` to the signed-in user, and forwards
   `/api/datyx/me` and `/api/datyx/datasources` to the datyx API
   (`DATYX_API_URL`) with the user's own token ([API](api.md)). The app
   signs in with Google (`google_sign_in`) using the client id the API
   publishes, sends the token on every call, and shows the account corner,
   a sign-in chip and the datyx card ([Welcome](welcome.md)). Settings in
   `.env.example`, `scripts/env.sh`, `scripts/api.sh`,
   `process-compose.yaml` and `compose.yaml`. Tests for the routes and
   the screen.

## 2026-10-29

1. **Separate the dev containers, images and Codespaces configurations by
   demo group.** HealthHub now opens in the datyx group's dev container,
   **datyx demos** (`.devcontainer/datyx/`), on the group's image
   `docker.io/aletyxcode/samples-and-demos-datyx` (`bash
   image/build-image.sh datyx`), which starts it with the datyx API, the
   datyx dashboard and the index page. Its own dev container,
   `.devcontainer/HealthHub/`, was removed. The start-up log is
   `startup.log` at the repository root. The README's codespace link
   points at the group's container. See [Development
   environment](dev-environment.md).

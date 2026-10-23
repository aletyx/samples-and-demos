# Development environment

Cellfie's environment is Contact Hub's, with its own names and ports;
[Mortgage Hub's spec](../../MortgageHub/specs/dev-environment.md)
explains the reasons behind each piece.

- [devbox.json](../devbox.json) manages the toolchain: Flutter,
  GNU Make and curl. [devbox.lock](../devbox.lock) is committed, and is
  the same as Mortgage Hub's and Contact Hub's, so the three use the same
  Flutter (Dart 3.13.0) and share one Nix store. All require Dart SDK
  `^3.13.0`.
- `devbox services up` ([process-compose.yaml](../process-compose.yaml)),
  run in this folder, starts:
  - the Flutter web server (`2-flutter-web`, via
    [scripts/flutter-web.sh](../scripts/flutter-web.sh), on the
    `web-server` device, so no Chrome is needed) on
    http://localhost:8930/app/ (`FLUTTER_WEB_PORT`), bound to 127.0.0.1
    (`CELLFIE_BIND_HOST`), with an HTTP readiness probe. On stop, its
    shutdown command kills whatever listens on the port;
  - the API (`3-api`, via [scripts/api.sh](../scripts/api.sh)) on
    http://localhost:8931 (`API_PORT`), with a readiness probe on
    `/api/health`. The script exports `AITYX_API_KEY` and `AITYX_URL` from
    the environment, else `.env`, to the server only. CORS allows the web
    app's origins (`ALLOWED_ORIGINS`);
  - the health monitor (`0-health-check`,
    [scripts/health-check.sh](../scripts/health-check.sh)), once both are
    ready. It first prints where to open the app,
    `http://localhost:8930/app/` and, in a codespace, the forwarded URL,
    and waits 5 s (`HEALTH_CHECK_DELAY`). Then every 15 s
    (`HEALTH_CHECK_INTERVAL`) one line with the time, 🌐 Web, 🔌 API
    (`/api/health`) and 🤖 aityx (✅ the API has its key, ⚪ it doesn't).
- The ports, 8930 and 8931, differ from Mortgage Hub's (8880, 8881) and
  Contact Hub's (8890, 8891), so all three can run at once.
- `devbox run web` runs only the web server, `devbox run api` only the API.
- The web app calls the API at `API_BASE_URL` (a dart-define). The dev
  server leaves it empty: the app calls `/api/` on its own origin, which
  the dev server proxies to the API (`web_dev_config.yaml`, generated from
  `API_PORT`, git-ignored). It also proxies the bare `/` to the API, which
  redirects it to `/app/`. `scripts/make.sh` passes `API_BASE_URL`, or
  `http://localhost:8931`.
- `bash scripts/model-test.sh` runs the Life model on aityx (see
  [Generation](generation.md#verified)); run it after changing the model.
  `dart run tool/catalogue.dart` in `cellfie_app/` regenerates the
  model's pattern catalogue (see [Patterns](patterns.md)).
- **Version**: `X.Y.Z`, X and Y from `version.X.txt` and `version.Y.txt`
  (0.1 today), Z the build time as `YYYYMMDDHHMM` UTC; the build number is
  the same time in Unix seconds
  ([scripts/version.sh](../scripts/version.sh)). It reaches the app as the
  `CELLFIE_VERSION` dart-define, shown in the app bar.
- **Builds**: the [Makefile](../Makefile) runs
  [scripts/make.sh](../scripts/make.sh): `web`, `android`, `ios` (macOS),
  `linux` (Linux), `all` (what the host can build) and `clean`, with
  `MODE`, `IOS_CODESIGN` and `WEB_BASE_HREF`.
- **Docker Compose** ([compose.yaml](../compose.yaml)): `docker compose up`
  runs the app with Docker alone on http://localhost:8930/app/, published
  on 127.0.0.1 unless `CELLFIE_BIND_HOST` says otherwise. `web`
  ([docker/web.Dockerfile](../docker/web.Dockerfile)) builds the release
  web app with the Flutter devbox.lock pins and serves it with nginx under
  `/app/`, redirecting `/` and proxying `/api/` to `api`
  ([docker/nginx.conf](../docker/nginx.conf)). `api`
  ([cellfie_api/Dockerfile](../cellfie_api/Dockerfile)) is the server
  compiled with `dart compile exe`, run from `scratch` as user 65534 and
  not published; Compose passes it `AITYX_API_KEY` and `AITYX_URL` from
  the environment, else `.env`, and `web` gets neither. Both have health
  checks (`api` runs `/app/bin/server healthcheck`), and `web` starts once
  `api` is healthy.
- **Dev container**
  ([.devcontainer/Cellfie/](../../.devcontainer/Cellfie)), named
  **Cellfie**: the same Containerfile and scripts as Contact Hub's
  (Devbox 0.18.1, Nix 2.35.0, the GitHub CLI and Flutter 3.47.0, pinned
  and checksum-verified), with `Cellfie/` as the app folder.
  `post-create.sh` reports whether `AITYX_API_KEY` arrived (never its
  value) and runs `devbox install`; `post-start.sh` starts
  `devbox services up -b` detached on every start, with a watcher that
  logs when `/app/` and `/api/health` answer; `public-port.sh` makes port
  8930 public (again on attach). Everything goes to
  `Cellfie/startup.log`, git-ignored, which holds no secrets. The
  container sets `CELLFIE_BIND_HOST=0.0.0.0`, forwards port 8930 only,
  and adds the Dart and Flutter extensions.
- **Codespaces secrets**: `devcontainer.json` declares `AITYX_API_KEY` and
  optional `AITYX_URL`,
  the same secret as Mortgage Hub's and Contact Hub's. Codespaces secrets
  belong to a user and are granted per repository, so a key granted to
  this repository for either reaches Cellfie too. GitHub asks for it on
  the creation page otherwise. `AITYX_URL` defaults to
  `https://api.aityx.ai`; `.env` overrides it. Both values are forwarded
  only to the API process. A local dev container uses `.env`.
- **Launch link**: the [README](../README.md#run-it-in-a-codespace) and the
  repository README have an **Open in GitHub Codespaces** badge with
  `devcontainer_path=.devcontainer/Cellfie/devcontainer.json` and
  `machine=standardLinux32gb`.

## Known limitations

- The dev container hasn't been started on Codespaces yet.
- No release, deploy or CI workflows.

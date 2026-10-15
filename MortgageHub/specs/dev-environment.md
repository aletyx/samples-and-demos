# Development environment

- [devbox.json](../devbox.json) manages the toolchain: Flutter, Python,
  GNU Make and curl. [devbox.lock](../devbox.lock) is committed.
- The app requires Dart SDK `^3.13.0`, which covers the Nix Flutter
  (Dart 3.13.0).
- Flutter web runs on the `web-server` device, so no Chrome is needed.
- `devbox services up` ([process-compose.yaml](../process-compose.yaml))
  starts:
  - the Flutter web server (`2-flutter-web`, via
    [scripts/flutter-web.sh](../scripts/flutter-web.sh)) on
    http://localhost:8880/app/ (`FLUTTER_WEB_PORT`), bound to 127.0.0.1
    (`MORTGAGEHUB_BIND_HOST`), with an HTTP readiness probe. On stop, its
    shutdown command kills whatever listens on the port, so Flutter's
    `dart` process doesn't keep serving the old build;
  - the API (`3-api`, via [scripts/api.sh](../scripts/api.sh)) on
    http://localhost:8881 (`API_PORT`), with a readiness probe on
    `/api/health`. The script exports `AITYX_API_KEY`, `AITYX_URL` and
    `ASSUMED_RATE` from `.env` to the server only. CORS allows the web
    app's origins (`ALLOWED_ORIGINS`);
  - the health monitor (`0-health-check`,
    [scripts/health-check.sh](../scripts/health-check.sh)), once the web
    server and the API are ready: every 15 s (`HEALTH_CHECK_INTERVAL`) one line, the
    time and each check as its emoji, a short label and ✅ / ❌, separated
    by ` · `. The checks are 🌐 Web, 🔌 API (`/api/health`) and 🤖 aityx (✅ the API
    has its key, ⚪ it doesn't). Sourcing the script defines
    `run_checks` (one pass) without starting the loop.
- `devbox run web` runs only the web server, `devbox run api` only the API.
- The web app calls the API at `API_BASE_URL` (a dart-define). The dev
  server leaves it empty: the app calls `/api/` on its own origin, which
  the dev server proxies to the API (`web_dev_config.yaml`, generated from
  `API_PORT`, git-ignored). `scripts/make.sh` passes `API_BASE_URL`, or
  `http://localhost:8881`.
- `bash scripts/model-test.sh` runs the mortgage rules on aityx with
  expected verdicts (see [Regulatory check](regulatory-check.md#verified)).
- **Version**: `X.Y.Z`, X and Y from `version.X.txt` and `version.Y.txt`
  (0.1 today), Z the build time as `YYYYMMDDHHMM` UTC; the build number is
  the same time in Unix seconds
  ([scripts/version.sh](../scripts/version.sh)). It reaches the app as the
  `MORTGAGEHUB_VERSION` dart-define.
- **Builds**: the [Makefile](../Makefile) runs
  [scripts/make.sh](../scripts/make.sh): `web`, `android`, `ios` (macOS),
  `linux` (Linux), `all` (what the host can build) and `clean`, with
  `MODE` (release, profile, debug), `IOS_CODESIGN` and `WEB_BASE_HREF`.
- **Docker Compose** ([compose.yaml](../compose.yaml)): `docker compose up`
  runs the app with Docker alone, on http://localhost:8880/app/
  (`FLUTTER_WEB_PORT`), published on 127.0.0.1 unless
  `MORTGAGEHUB_BIND_HOST` says otherwise. Two services:
  - `web` ([docker/web.Dockerfile](../docker/web.Dockerfile)): installs
    the Flutter devbox.lock pins (3.47.0; on x64 the release archive
    checked against its SHA-256, on arm64 the git tag, as in the dev
    container), runs `scripts/make.sh web` with `WEB_BASE_HREF=/app/` and
    an empty `API_BASE_URL`, and serves the build with nginx 1.29, which
    redirects `/` to `/app/`, falls back to `index.html` for the app's
    routes and proxies `/api/` to `api`
    ([docker/nginx.conf](../docker/nginx.conf)). Its build context is this
    folder, narrowed by `web.Dockerfile.dockerignore` to the app, the two
    scripts and the version files; the folder's own `.dockerignore` is
    left as it was;
  - `api` ([mortgagehub_api/Dockerfile](../mortgagehub_api/Dockerfile)):
    `dart compile exe` with Dart 3.13.0, run from `scratch` with the Dart
    image's `/runtime/` (libc, CA certificates) as user 65534, the model
    beside it in `/app/models`. It binds 0.0.0.0:8881 inside the network
    and is not published. Compose passes it `AITYX_API_KEY`, `AITYX_URL`
    and `ASSUMED_RATE` (6.5 when empty) from the environment, else `.env`;
    `web` gets none of them.
  Both have Docker health checks, every 15 s: `api` runs
  `/app/bin/server healthcheck`, which asks its own `/api/health` on
  127.0.0.1 and exits 0 when it answers `ok` (the `scratch` image has no
  shell or curl); `web` fetches `/app/` and, through its proxy,
  `/api/health` with busybox `wget`. `web` starts once `api` is healthy,
  and `docker compose up --wait` returns once both are. There is no hot
  reload; both restart `unless-stopped`.
- **Dev container**
  ([.devcontainer/Mortgage Hub/](../../.devcontainer/Mortgage%20Hub)): at
  the root of the samples repository, not in this folder, because that is
  the only place GitHub looks for one. It is named **Mortgage Hub**, so the
  configuration is identifiable when creating a codespace on a repository
  that holds several samples, and opens with a header saying what the
  project is and linking the repository, aityx.ai, aletyx.com and
  nu01.com. Microsoft's `ubuntu-24.04`
  base, with Devbox 0.18.1 and Nix 2.35.0 pinned and checked against their
  published SHA-256.
  [post-create.sh](../../.devcontainer/Mortgage%20Hub/post-create.sh)
  resolves this folder from its own location and moves there, fetches the
  locked Nix store paths from cache.nixos.org, then runs `devbox install`,
  and passes `GITHUB_TOKEN` to Nix so api.github.com doesn't rate-limit
  it. It reports whether `AITYX_API_KEY` arrived, never its value. The
  container sets `MORTGAGEHUB_BIND_HOST=0.0.0.0`, forwards port 8880 and
  adds the Dart and Flutter extensions.
- **The editor's Flutter SDK**: devbox keeps the toolchain in the
  workspace, not on the PATH, so the Dart extension reported "Could not
  find a Flutter SDK". After `devbox install`, `post-create.sh` links
  devbox's profile — a complete SDK, with `bin/flutter`,
  `bin/cache/dart-sdk` and `packages/flutter_tools` — to `~/flutter`, a
  fixed path that does not depend on the repository name.
  `devcontainer.json` points `dart.flutterSdkPath` there and puts
  `~/flutter/bin` on the PATH of every terminal, so `flutter` and `dart`
  work outside `devbox shell` too. It is the same Flutter that
  `devbox.lock` pins, linked rather than copied, so the editor and the
  builds can never be on different versions. Nothing is copied into the image,
  so the build context is the dev container folder alone.
- **Codespaces secret**: `devcontainer.json` declares `AITYX_API_KEY`
  alone under `secrets`, so GitHub asks the person creating a codespace
  for their own key, keeps it against their account and passes it in as an
  environment variable. It is required: without it the app runs but the
  regulatory check cannot. Nothing else is asked for, because `AITYX_URL`
  defaults to `https://api.aityx.ai` and `ASSUMED_RATE` to 6.5; both are
  overridden in `.env` when needed (a stage key, for instance, works only
  against `https://console-stage.aityx.ai`). The repository ships no key.
  A local dev container uses `.env`, which the scripts already fall back
  to.
- **Launch link**: the [README](../README.md#run-it-in-a-codespace) has an
  **Open in GitHub Codespaces** badge pointing at
  `codespaces.new/aletyx/samples-and-demos` with `devcontainer_path` set
  to this configuration and `machine=standardLinux32gb`, the 4-core,
  16 GB machine the Flutter and Nix builds want.

## Known limitations

- The dev container hasn't been built yet, so neither the image nor the
  Codespaces secrets prompt has been exercised on GitHub.
- No release, deploy or CI workflows: the API runs only locally, under
  devbox or Docker Compose.

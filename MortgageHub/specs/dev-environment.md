# Development environment

- [devbox.json](../devbox.json) manages the toolchain: Flutter,
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
- **Dev container** ([.devcontainer/](../../.devcontainer)): the
  samples repository's default one, **All demos**, at the root of the
  repository, not in this folder, because that is the only place GitHub
  looks for one. It starts every demo (each folder with a `devbox.json`
  and a `process-compose.yaml`, this one among them) and the index page
  with the repository's `start-all.sh`. Mortgage Hub's own dev container,
  which started only this app and which the other demos' were copied
  from, is archived in
  [.devcontainer/archive/MortgageHub/](../../.devcontainer/archive/MortgageHub)
  and is no longer offered when creating a codespace (GitHub lists only
  `.devcontainer/devcontainer.json` and `.devcontainer/<name>/`). The
  default container opens with a header saying what it starts and
  linking the repository, aityx.ai, aletyx.com and nu01.com. Microsoft's
  `ubuntu-24.04` base, with Devbox 0.18.1 and Nix 2.35.0 pinned and
  checked against their published SHA-256; `hostRequirements` asks for
  8 cores and 32 GB, since six apps compile at once.
  [post-create.sh](../../.devcontainer/post-create.sh) runs `devbox
  install` in each demo's folder in turn, which copies the locked store
  paths from cache.nixos.org (all lock the same Flutter, so the store is
  filled once), and passes `GITHUB_TOKEN` to Nix so api.github.com
  doesn't rate-limit it. It reports whether `AITYX_API_KEY` arrived,
  never its value. The container sets every demo's `*_BIND_HOST` to
  `0.0.0.0` (`MORTGAGEHUB_BIND_HOST` for this one, `INDEX_BIND_HOST` for
  the index), forwards 8800 and the five web ports (8880 to 8920), and
  adds the Dart and Flutter extensions.
- **The editor's Flutter SDK**: the image carries Flutter 3.47.0, the
  version `devbox.lock` pins, in `/opt/flutter`: on x64 the release
  archive, checked against the SHA-256 in `releases_linux.json`; on arm64,
  where Flutter publishes no Linux archive, the release tag from git. Its
  web artifacts are precached and analytics are off. `devcontainer.json`
  points `dart.flutterSdkPath` there and puts `/opt/flutter/bin` on the
  PATH of every terminal. It is in the image because devbox's own Flutter
  appears only after `post-create.sh` has run `devbox install`, and the
  Dart extension, finding no SDK when VS Code attached, offered to
  download one. Inside `devbox shell` and `devbox services up` devbox's
  Flutter comes first; the two must be kept on the same version. Nothing
  is copied into the image, so the build context is the dev container
  folder alone.
- **Starts by itself**: `postStartCommand` runs
  [post-start.sh](../../.devcontainer/post-start.sh) on every start
  (after `post-create.sh` on the first), which runs `./start-all.sh`
  detached with `WAIT=900`, then `public-port.sh`. Every port is
  forwarded as plain HTTP; only the index's 8800 has `onAutoForward:
  openBrowserOnce`, the others are `silent`, since the index is up in
  seconds and links each app once it answers (with its forwarded URL, in
  a codespace). The web server proxies the bare `/` to the API, which
  redirects it to `/app/` (the proxy turns that into `/app`, which
  serves the same page), so the forwarded port's URL opens the app as it
  is, as nginx does under Docker Compose.
- **Start-up log**: `startup.log` at the root of the repository
  (git-ignored, as every `*.log`), written through
  [startup-log.sh](../../.devcontainer/startup-log.sh), which the three
  scripts source. Each line has a UTC time and a tag: `post-create`
  (with each `devbox install`'s output and duration), `post-start`,
  `start-all` (`start-all.sh`'s output: each demo's start and the line
  saying when it answers, or that it didn't within 15 minutes) and
  `public-port`. `post-create.sh` and `post-start.sh` first log the
  facts a failed start comes down to: user, architecture, the codespace,
  whether `AITYX_API_KEY` and `GITHUB_TOKEN` are set (never their
  values), `AITYX_URL`, devbox's and Nix's versions, whether each demo's
  `.devbox` exists and the free disk. It's in the workspace so a user can
  download it from the Explorer and send it; the README asks them to when
  the app doesn't start.
- **Public web ports**:
  [public-port.sh](../../.devcontainer/public-port.sh) in a codespace
  makes the index's port and each demo's web port (8880 for this app)
  public with `gh codespace ports visibility`, each one retried in the
  background (every 10 s, for up to 20 minutes) until it is forwarded,
  since the demos come up one by one. `devcontainer.json` has no setting
  for it. Only the web ports are public: the API's 8881 is not forwarded,
  and the app reaches it through the web server's `/api/` proxy. It runs again from
  `postAttachCommand`, because a visibility set at start does not always
  stick; a second run while one is still retrying does nothing. An
  organization policy can forbid public ports, in which case the port
  stays private. The READMEs tell the user to check the port's visibility
  in the Ports panel and set it to Public by hand if needed.
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
- **Setup screenshots**: the README's codespace steps show the
  *New secret* form and the *Create a new codespace* page
  ([docs/images/](../docs/images/)), so a reader can check that the key is
  associated with the repository before creating the codespace.

## Known limitations

- The dev container hasn't been built yet, so neither the image nor the
  Codespaces secrets prompt has been exercised on GitHub.
- No release, deploy or CI workflows: the API runs only locally, under
  devbox or Docker Compose.

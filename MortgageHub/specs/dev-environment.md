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
- **Dev container**
  ([.devcontainer/Mortgage Hub/](../../.devcontainer/Mortgage%20Hub)): at
  the root of the samples repository, not in this folder, because that is
  the only place GitHub looks for one. It is named **Mortgage Hub demo
  app**, so the configuration is identifiable when creating a codespace on
  a repository that holds several samples. Microsoft's `ubuntu-24.04`
  base, with Devbox 0.18.1 and Nix 2.35.0 pinned and checked against their
  published SHA-256.
  [post-create.sh](../../.devcontainer/Mortgage%20Hub/post-create.sh)
  resolves this folder from its own location and moves there, fetches the
  locked Nix store paths from cache.nixos.org, then runs `devbox install`,
  and passes `GITHUB_TOKEN` to Nix so api.github.com doesn't rate-limit
  it. It reports whether `AITYX_API_KEY` arrived, never its value. The
  container sets `MORTGAGEHUB_BIND_HOST=0.0.0.0`, forwards port 8880 and
  adds the Dart and Flutter extensions. Nothing is copied into the image,
  so the build context is the dev container folder alone.
- **Codespaces secrets**: `devcontainer.json` declares `AITYX_API_KEY`,
  `AITYX_URL` and `ASSUMED_RATE` under `secrets`, so GitHub asks the
  person creating a codespace for their own values, keeps them against
  their account and passes them in as environment variables. The
  repository ships no key. A local dev container uses `.env` instead,
  which the scripts already fall back to.

## Known limitations

- The dev container hasn't been built yet, so neither the image nor the
  Codespaces secrets prompt has been exercised on GitHub.
- No release, deploy or CI workflows: the API runs only locally.

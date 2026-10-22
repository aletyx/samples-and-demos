# Development environment

Contact Hub's environment is Mortgage Hub's, with its own names and ports;
[Mortgage Hub's spec](../../MortgageHub/specs/dev-environment.md)
explains the reasons behind each piece.

- [devbox.json](../devbox.json) manages the toolchain: Flutter,
  GNU Make, curl and Ollama (0.40.0, for the local model). [devbox.lock](../devbox.lock) is committed; its Flutter,
  Make and curl pins are Mortgage Hub's, so the two use the same Flutter (Dart
  3.13.0) and share one Nix store. Both projects require Dart SDK
  `^3.13.0`.
- `devbox services up` ([process-compose.yaml](../process-compose.yaml)),
  run in this folder, starts:
  - the Flutter web server (`2-flutter-web`, via
    [scripts/flutter-web.sh](../scripts/flutter-web.sh), on the
    `web-server` device, so no Chrome is needed) on
    http://localhost:8890/app/ (`FLUTTER_WEB_PORT`), bound to 127.0.0.1
    (`CONTACTHUB_BIND_HOST`), with an HTTP readiness probe. On stop, its
    shutdown command kills whatever listens on the port;
  - the local model (`1-ollama`, via
    [scripts/ollama.sh](../scripts/ollama.sh)): `ollama serve` at
    `OLLAMA_URL` (default `http://127.0.0.1:11434`), unless something
    already answers there (the Ollama app, say), in which case it uses
    that; then `ollama pull` of `OLLAMA_MODEL` (default `qwen3:1.7b`,
    about 1.4 GB, once, into `~/.ollama`). Ready, by an exec probe
    (`scripts/ollama.sh ready`), when Ollama lists the model; the API
    starts without waiting and answers 503 to a routing until then;
  - the API (`3-api`, via [scripts/api.sh](../scripts/api.sh)) on
    http://localhost:8891 (`API_PORT`), with a readiness probe on
    `/api/health`. The script exports `AITYX_API_KEY`, `AITYX_URL`,
    `OLLAMA_URL` and `OLLAMA_MODEL` from the environment, else `.env`, to
    the server only. CORS allows the web app's origins (`ALLOWED_ORIGINS`);
  - the health monitor (`0-health-check`,
    [scripts/health-check.sh](../scripts/health-check.sh)), once the web
    app and the API are ready. It first prints where to open the app,
    `http://localhost:8890/app/` and, in a codespace, the forwarded URL
    (`https://$CODESPACE_NAME-8890.$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN/app/`),
    and waits 5 s (`HEALTH_CHECK_DELAY`). Then every 15 s
    (`HEALTH_CHECK_INTERVAL`) one line with the time, 🌐 Web, 🔌 API
    (`/api/health`), 🤖 aityx (✅ the API has its key, ⚪ it doesn't) and
    🧠 Local model (✅ Ollama lists it, ⚪ not yet: starting, or pulling).
- The ports, 8890 and 8891, differ from Mortgage Hub's 8880 and 8881, so
  both can run at once.
- `devbox run web` runs only the web server, `devbox run api` only the
  API, `devbox run local-model` only Ollama and the pull.
- The web app calls the API at `API_BASE_URL` (a dart-define). The dev
  server leaves it empty: the app calls `/api/` on its own origin, which
  the dev server proxies to the API (`web_dev_config.yaml`, generated from
  `API_PORT`, git-ignored). It also proxies the bare `/` to the API, which
  redirects it to `/app/`. `scripts/make.sh` passes `API_BASE_URL`, or
  `http://localhost:8891`.
- `bash scripts/model-test.sh` runs the routing model's rules on aityx at
  the policy's limits (see [Order policy](order-policy.md#verified)); run
  it after changing the model. `dart run tool/route_samples.dart` in
  `contacthub_app/` routes every sample through a running API
  (`--api`, default `http://localhost:8891`) and says where each went
  against its label, with `--save DIR` keeping each answer: how the test
  fixtures are made (see [Reading with a local model](reading.md#verified)).
- **Version**: `X.Y.Z`, X and Y from `version.X.txt` and `version.Y.txt`
  (0.1 today), Z the build time as `YYYYMMDDHHMM` UTC; the build number is
  the same time in Unix seconds
  ([scripts/version.sh](../scripts/version.sh)). It reaches the app as the
  `CONTACTHUB_VERSION` dart-define.
- **Builds**: the [Makefile](../Makefile) runs
  [scripts/make.sh](../scripts/make.sh): `web`, `android`, `ios` (macOS),
  `linux` (Linux), `all` (what the host can build) and `clean`, with
  `MODE`, `IOS_CODESIGN` and `WEB_BASE_HREF`.
- **Docker Compose** ([compose.yaml](../compose.yaml)): `docker compose up`
  runs the app with Docker alone on http://localhost:8890/app/, published
  on 127.0.0.1 unless `CONTACTHUB_BIND_HOST` says otherwise. `web`
  ([docker/web.Dockerfile](../docker/web.Dockerfile)) builds the release
  web app with the Flutter devbox.lock pins and serves it with nginx under
  `/app/`, redirecting `/` and proxying `/api/` to `api`
  ([docker/nginx.conf](../docker/nginx.conf)). `api`
  ([contacthub_api/Dockerfile](../contacthub_api/Dockerfile)) is the
  server compiled with `dart compile exe`, run from `scratch` as user
  65534 and not published; Compose passes it `AITYX_API_KEY` and
  `AITYX_URL` from the environment, else `.env`, `OLLAMA_URL=http://ollama:11434`
  and `OLLAMA_MODEL`, and `web` gets none. `ollama` (the
  `ollama/ollama:0.40.0` image, on the CPU) serves the local model and
  pulls `OLLAMA_MODEL` on first start into the `ollama` volume; it is
  healthy once `ollama show` finds the model, and not published. All
  three have health checks (`api` runs `/app/bin/server healthcheck`);
  `api` starts with `ollama` without waiting for the pull, and `web`
  starts once `api` is healthy.
- **Dev container**
  ([.devcontainer/ContactHub/](../../.devcontainer/ContactHub)), named
  **Contact Hub**: the same Containerfile and scripts as Mortgage Hub's
  (Devbox 0.18.1, Nix 2.35.0, the GitHub CLI and Flutter 3.47.0, pinned
  and checksum-verified), with `ContactHub/` as the app folder.
  `post-create.sh` reports whether `AITYX_API_KEY` arrived (never its
  value) and runs `devbox install`, which installs Ollama too;
  `post-start.sh` starts `devbox services up -b` detached on every
  start, which also pulls the local model on the first one (about
  1.4 GB), with a watcher that logs when `/app/` and `/api/health`
  answer; `public-port.sh` makes port
  8890 public (again on attach). Everything goes to
  `ContactHub/startup.log`, git-ignored, which holds no secrets. The
  container sets `CONTACTHUB_BIND_HOST=0.0.0.0`, forwards port 8890 only,
  and adds the Dart and Flutter extensions.
- **Codespaces secret**: `devcontainer.json` declares `AITYX_API_KEY`,
  the same secret as Mortgage Hub's. Codespaces secrets belong to a user
  and are granted per repository, so a key granted to this repository for
  Mortgage Hub reaches Contact Hub too; GitHub never returns a secret's
  value, so it can't be copied, and doesn't need to be. GitHub asks for it
  on the creation page otherwise. `AITYX_URL` defaults to
  `https://api.aityx.ai`; `.env` overrides it. A local dev container uses
  `.env`.
- **Launch link**: the [README](../README.md#run-it-in-a-codespace) and the
  repository README have an **Open in GitHub Codespaces** badge with
  `devcontainer_path=.devcontainer/ContactHub/devcontainer.json` and
  `machine=standardLinux32gb`.

## Known limitations

- The dev container hasn't been started on Codespaces yet.
- No release, deploy or CI workflows.

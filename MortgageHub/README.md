# Mortgage Hub

Mortgage Hub brings a home buyer's mortgage, from application to closing,
into one place. For now the app is a welcome page with a form to request
a mortgage proposal, and a regulatory check that says whether a lender can
process it under current US rules, run by [aityx.ai](https://aityx.ai).

## Technology

| Part | Technology |
|---|---|
| App ([mortgagehub_app/](mortgagehub_app)) | [Flutter](https://flutter.dev) (Dart): web, Android, iOS and Linux from one codebase |
| API ([mortgagehub_api/](mortgagehub_api)) | Dart (`dart:io`): holds the aityx key and runs the regulatory check |
| Rules | An [aityx.ai](https://aityx.ai) decision model ([proposal-check.json](mortgagehub_api/models/proposal-check.json)) |
| Dev environment | [Devbox](https://www.jetify.com/devbox) (Nix) in a [Dev Container](https://containers.dev/), process-compose for the services |

The toolchain is pinned in [devbox.json](devbox.json) and locked in
[devbox.lock](devbox.lock): Flutter, Python, GNU Make and curl.

## Run it locally with devbox

1. Install [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/).
2. For the regulatory check, put the aityx settings in `.env` (see
   [.env.example](.env.example)): `AITYX_API_KEY`, and
   `AITYX_URL=https://console-stage.aityx.ai` for a stage key. Check them
   with `bash scripts/aityx-check.sh`.
3. From this folder:

   ```bash
   devbox services up           # add --pcflags "--tui=false" when not in a terminal
   ```

That starts, from [process-compose.yaml](process-compose.yaml):

| URL | What |
|---|---|
| http://localhost:8880/app/ | The Flutter app in web mode ([scripts/flutter-web.sh](scripts/flutter-web.sh)). Press `r` in its terminal to hot reload |
| http://localhost:8881/api/health | The API ([scripts/api.sh](scripts/api.sh)) |

A `health-check` monitor logs one line every 15 s (set
`HEALTH_CHECK_INTERVAL` to change it): the time, then each check as its
emoji, a short label and ✅ ok / ❌ failed (🤖 aityx is ⚪ when the API
has no key):

```
2026-10-13 12:35:54 🌐 Web ✅ · 🔌 API ✅ · 🤖 aityx ✅
```

Stop everything with `devbox services stop`. To run only the app, use
`devbox run web` (set `FLUTTER_WEB_PORT` to change the port); only the
API, `devbox run api` (`API_PORT`).

### Building the binaries

The [Makefile](Makefile) builds release binaries through
[scripts/make.sh](scripts/make.sh):

```bash
make            # every platform this host can build
make web        # mortgagehub_app/build/web/
make android    # mortgagehub_app/build/app/outputs/flutter-apk/app-release.apk
make ios        # mortgagehub_app/build/ios/iphoneos/Runner.app (macOS, unsigned)
make linux      # mortgagehub_app/build/linux/<arch>/release/bundle/ (Linux only)
make clean
```

Pass `MODE=profile` or `MODE=debug` for other build modes, and
`IOS_CODESIGN=1` to sign the iOS build (this needs a signing team in Xcode).
The version is `X.Y.Z`: X and Y from [version.X.txt](version.X.txt) and
[version.Y.txt](version.Y.txt), Z the build time (see
[scripts/version.sh](scripts/version.sh)).

## Run it in a dev container

Open this folder in VS Code and choose **Reopen in Container**. The
[Containerfile](.devcontainer/Containerfile) starts from Microsoft's
`ubuntu-24.04` devcontainer base image and installs pinned, checksum-verified
releases of Devbox and Nix. On first start,
[post-create.sh](.devcontainer/post-create.sh) downloads the locked Nix
store paths and runs `devbox install`. Then run
`devbox services up --pcflags "--tui=false"` and open the forwarded port
**8880** at `/app/`. Export `GITHUB_TOKEN` (for example
`export GITHUB_TOKEN=$(gh auth token)`) before opening it if
`devbox install` fails with HTTP 403.

## Contributing

1. Create a branch from an up-to-date `main`.
2. Make one change per pull request, with its tests. Run `flutter analyze`
   and `flutter test` in `mortgagehub_app/`, and `dart analyze` and
   `dart test` in `mortgagehub_api/`.
3. Update the matching feature spec in [specs/](specs/) and add an entry to
   [specs/requests.md](specs/requests.md).
4. Open a pull request against `main`.

## Learn more

- [specs/](specs/README.md): the specification of every feature.

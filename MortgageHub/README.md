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
2. For the regulatory check, put your own aityx settings in `.env` (see
   [.env.example](.env.example)): `AITYX_API_KEY`, and
   `AITYX_URL=https://console-stage.aityx.ai` for a stage key. In a
   codespace GitHub asks for the key instead; see
   [Run it in a codespace](#run-it-in-a-codespace). Check them
   with `bash scripts/aityx-check.sh`, and the mortgage rules with
   `bash scripts/model-test.sh`.
3. From this folder:

   ```bash
   devbox services up           # add --pcflags "--tui=false" when not in a terminal
   ```

That starts, from [process-compose.yaml](process-compose.yaml):

| URL | What |
|---|---|
| http://localhost:8880/app/ | The Flutter app in web mode ([scripts/flutter-web.sh](scripts/flutter-web.sh)). Press `r` in its terminal to hot reload |
| http://localhost:8881/api/health | The API ([scripts/api.sh](scripts/api.sh)); the web app reaches it as `/api/` on its own origin, through the dev server's proxy |

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

## Run it in a codespace

### 1. Set your aityx key — required

The regulatory check runs on [aityx.ai](https://aityx.ai), and it needs an
API key. The key is always **yours**: none ships with this repository and
none is built into the container. Without it the codespace still starts and
the app still opens, but the regulatory check — what this demo exists to
show — cannot run.

Set it once, before launching:

1. Open your aityx console's **API keys** page and copy a key.
2. Go to
   [github.com/settings/codespaces](https://github.com/settings/codespaces).
3. Under **Codespaces secrets**, choose **New secret**.
4. Name it exactly `AITYX_API_KEY`, paste the key as the value, and give
   it access to the `aletyx/samples-and-demos` repository.

![The New secret form: name AITYX_API_KEY, the key as the value, and access to aletyx/samples-and-demos](docs/images/codespaces-new-secret.png)

If you skip this, GitHub asks for the key on the codespace creation page,
because [devcontainer.json](../.devcontainer/Mortgage%20Hub/devcontainer.json)
lists it as a required secret. Either way GitHub keeps it against your
account and passes it to the container as an environment variable: it is
never written to disk there, never committed, and never reaches the Flutter
app.

Nothing else needs setting. The API URL defaults to `https://api.aityx.ai`
and the payment estimate's rate to 6.5%. To change either, put `AITYX_URL`
or `ASSUMED_RATE` in `.env` (see [.env.example](.env.example)) — a stage
key, for instance, works only against `https://console-stage.aityx.ai`.

### 2. Launch it

[![Open Mortgage Hub in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FMortgage%20Hub%2Fdevcontainer.json&machine=standardLinux32gb)

That link opens this repository's **Mortgage Hub** dev container on a
4-core machine (16 GB RAM), which is what the Flutter and Nix builds want.
To choose for yourself instead, use *Code → Codespaces → New with
options* and pick **Mortgage Hub** as the dev container configuration —
the repository holds several samples, so the configuration matters.

The creation page should look like this: **Mortgage Hub** as the dev
container configuration, a 4-core machine, and `AITYX_API_KEY` under
*Recommended secrets*, ticked as associated with the repository. If it is
not ticked, the secret does not reach this repository; go back to step 1.

![The Create a new codespace page, with Mortgage Hub, 4-core and AITYX_API_KEY associated with the repository](docs/images/create-codespace.png)

### 3. Run the app

On first start,
[post-create.sh](../.devcontainer/Mortgage%20Hub/post-create.sh) moves to
this folder, downloads the locked Nix store paths and runs `devbox
install`; it also says whether your key arrived. Then:

```bash
devbox services up --pcflags "--tui=false"
```

and open the forwarded port **8880** at `/app/`. Export `GITHUB_TOKEN` (for
example `export GITHUB_TOKEN=$(gh auth token)`) before `devbox install` if
it fails with HTTP 403.

## Run it in a dev container locally

Open the repository root in VS Code and choose **Reopen in Container**,
then **Mortgage Hub**. The dev container lives at the root of the
repository, in [.devcontainer/Mortgage Hub/](../.devcontainer/Mortgage%20Hub),
because that is where GitHub looks for one.

The [Containerfile](../.devcontainer/Mortgage%20Hub/Containerfile) starts
from Microsoft's `ubuntu-24.04` devcontainer base image and installs
pinned, checksum-verified releases of Devbox and Nix.

Codespaces secrets are a GitHub feature, so set the key here by copying
[.env.example](.env.example) to `.env` and filling in `AITYX_API_KEY`. The
scripts read the environment first and fall back to `.env`, so the same
commands work either way.

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

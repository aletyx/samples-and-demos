# Contact Hub

Contact Hub lets someone ask anything and gets the question to the right
department or person, with the checks it needs run on the way. For now the
welcome page takes the request, typed, dictated (speech is recognized in
the browser, so no audio leaves the device) or picked from a sample, and
the routing screen says where it went: [Jev](https://aityx.ai/docs/coming-from-jev)
classifies and checks the message and a decision model on
[aityx.ai](https://aityx.ai) picks the department, the person and the
priority. For a request about an order, it applies the store's policy to
the order's dates and amounts (refund within 30 days, store credit within
60, warranty, restocking fee, price drops, cancellations...) and says how
much is paid back, and by when. It shows why, and the aityx call itself,
with links that jump to exactly the JSON behind each item.

## Technology

| Part | Technology |
|---|---|
| App ([contacthub_app/](contacthub_app)) | [Flutter](https://flutter.dev) (Dart): web, Android, iOS and Linux from one codebase |
| API ([contacthub_api/](contacthub_api)) | Dart (`dart:io`): holds the [aityx](https://aityx.ai) key; for now only `/api/health` |
| Dev environment | [Devbox](https://www.jetify.com/devbox) (Nix) in a [Dev Container](https://containers.dev/), process-compose for the services; or [Docker Compose](compose.yaml) |

The toolchain is pinned in [devbox.json](devbox.json) and locked in
[devbox.lock](devbox.lock): Flutter, GNU Make and curl. It is the same
lock as Mortgage Hub's, so the two share one Nix store.

## Run it locally with devbox

1. Install [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/).
2. Put your [aityx](https://aityx.ai) key in `.env` (copy
   [.env.example](.env.example)): the same `AITYX_API_KEY` as Mortgage
   Hub's, for instance `grep '^AITYX_' ../MortgageHub/.env > .env`.
   Without it the app runs, but **Send** can't route.
3. From this folder:

   ```bash
   devbox services up           # add --pcflags "--tui=false" when not in a terminal
   ```

That starts, from [process-compose.yaml](process-compose.yaml):

| URL | What |
|---|---|
| http://localhost:8890/app/ | The Flutter app in web mode ([scripts/flutter-web.sh](scripts/flutter-web.sh)). Press `r` in its terminal to hot reload |
| http://localhost:8891/api/health | The API ([scripts/api.sh](scripts/api.sh)); the web app reaches it as `/api/` on its own origin, through the dev server's proxy |

The ports are 8890 and 8891, so Contact Hub runs alongside Mortgage Hub
(8880 and 8881). The first start compiles the app, which takes a minute
or so. Type a request, or press the microphone beside the field and say
it: the browser asks for the microphone the first time, and Chrome or
Edge install their on-device English pack, while other browsers download
a small speech model (see [Request box](specs/request.md)). Or pick one
from **Try a sample**: one for each department, and two for the checks.
**Send** routes it (see [Routing](specs/routing.md)).

Once both are ready, the `health-check` monitor prints where to open the
app (in a codespace, its forwarded URL too), waits 5 s
(`HEALTH_CHECK_DELAY`), then logs one line every 15 s
(`HEALTH_CHECK_INTERVAL`); 🤖 [aityx](https://aityx.ai) is ⚪ when the API
has no key:

```
Contact Hub is up. Open the app at:
  http://localhost:8890/app/
Health checks start in 5 s, then every 15 s.
2026-10-21 11:42:10 🌐 Web ✅ · 🔌 API ✅ · 🤖 aityx ✅
```

Stop everything with `devbox services stop`. To run only the app, use
`devbox run web` (set `FLUTTER_WEB_PORT` to change the port); only the
API, `devbox run api` (`API_PORT`).

### Building the binaries

The [Makefile](Makefile) builds release binaries through
[scripts/make.sh](scripts/make.sh):

```bash
make            # every platform this host can build
make web        # contacthub_app/build/web/
make android    # contacthub_app/build/app/outputs/flutter-apk/app-release.apk
make ios        # contacthub_app/build/ios/iphoneos/Runner.app (macOS, unsigned)
make linux      # contacthub_app/build/linux/<arch>/release/bundle/ (Linux only)
make clean
```

Pass `MODE=profile` or `MODE=debug` for other build modes, and
`IOS_CODESIGN=1` to sign the iOS build (this needs a signing team in Xcode).
The version is `X.Y.Z`: X and Y from [version.X.txt](version.X.txt) and
[version.Y.txt](version.Y.txt), Z the build time (see
[scripts/version.sh](scripts/version.sh)).

## Run it with Docker Compose

With only [Docker](https://docs.docker.com/get-docker/) installed (no
devbox, no Flutter), from this folder:

```bash
docker compose up --build
```

and open http://localhost:8890/app/. [compose.yaml](compose.yaml) builds
and starts two services:

| Service | What |
|---|---|
| `web` | The app's release web build ([docker/web.Dockerfile](docker/web.Dockerfile)), served by nginx under `/app/`, with `/api/` proxied to the API ([docker/nginx.conf](docker/nginx.conf)) |
| `api` | The API compiled to a native executable ([contacthub_api/Dockerfile](contacthub_api/Dockerfile)); not published, reached only through `web` |

For the key, copy [.env.example](.env.example) to `.env` and fill in
`AITYX_API_KEY` (or export it); it goes to the API only. The first build
takes a few minutes (it downloads Flutter); later ones
reuse Docker's cache. Set `FLUTTER_WEB_PORT` to change the port; the app
is bound to 127.0.0.1 unless you set `CONTACTHUB_BIND_HOST=0.0.0.0`. Stop
it with `docker compose down`. Both services have health checks, so
`docker compose up --wait` returns once they are healthy. There is no hot
reload: rebuild after a change.

## Run it in a codespace

[![Open Contact Hub in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FContactHub%2Fdevcontainer.json&machine=standardLinux32gb)

That link opens this repository's **Contact Hub** dev container on a
4-core machine (16 GB RAM), which is what the Flutter and Nix builds want.
To choose for yourself instead, use *Code → Codespaces → New with
options* and pick **Contact Hub** as the dev container configuration —
the repository holds several samples, so the configuration matters.

The codespace uses your [aityx](https://aityx.ai) key, the same
`AITYX_API_KEY` Codespaces secret as Mortgage Hub's. GitHub keeps
Codespaces secrets per user and grants them per repository, so if your key
already reaches this repository for Mortgage Hub, there is nothing to do.
Otherwise add it at
[github.com/settings/codespaces](https://github.com/settings/codespaces)
(**New secret**, name `AITYX_API_KEY`, access to
`aletyx/samples-and-demos`), or enter it when GitHub asks on the creation
page. Without it the app runs, but **Send** can't route.

On first start,
[post-create.sh](../.devcontainer/ContactHub/post-create.sh) moves to
this folder, says whether your key arrived and runs `devbox install`. Then, on that and every later
start, [post-start.sh](../.devcontainer/ContactHub/post-start.sh) starts
the services in the background and makes port **8890** public. There is
nothing to run: once the app has compiled, open port 8890 from the
**Ports** panel (Codespaces may open it in a browser tab for you). Its
bare URL redirects to the app at `/app/`.

Watch the services with `devbox services attach`, restart them with
`devbox services restart`, and stop them with `devbox services stop`.

**If the app doesn't start, send us `ContactHub/startup.log`.** Every
step of the codespace's start goes there, timestamped, including a line
saying when the web app and the API first answered. It holds no secrets.

**Check the port's visibility.** In the **Ports** panel, the
*Visibility* column for 8890 should say **Public**. If it says
**Private**, right-click the port, choose **Port Visibility → Public**
and reload the app. If `devbox install` fails with HTTP 403, export
`GITHUB_TOKEN` (for example `export GITHUB_TOKEN=$(gh auth token)`) and
run it again.

## Run it in a dev container locally

Open the repository root in VS Code and choose **Reopen in Container**,
then **Contact Hub**. The dev container lives at the root of the
repository, in [.devcontainer/ContactHub/](../.devcontainer/ContactHub),
because that is where GitHub looks for one. Its
[Containerfile](../.devcontainer/ContactHub/Containerfile) is Mortgage
Hub's: Microsoft's `ubuntu-24.04` base with pinned, checksum-verified
Devbox, Nix, the GitHub CLI and Flutter.

## Contributing

1. Create a branch from an up-to-date `main`.
2. Make one change per pull request, with its tests. Run `flutter analyze`
   and `flutter test` in `contacthub_app/`, and `dart analyze` and
   `dart test` in `contacthub_api/`. After changing the model, `bash
   scripts/model-test.sh` runs its rules on aityx, and `dart run
   tool/route_samples.dart` in `contacthub_app/` routes every sample
   through the running API.
3. Update the matching feature spec in [specs/](specs/) and add an entry to
   [specs/requests.md](specs/requests.md).
4. Open a pull request against `main`.

## Learn more

- [specs/](specs/README.md): the specification of every feature.

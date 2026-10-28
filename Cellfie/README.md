# Cellfie

Every generation, the cells take a picture of themselves, and aityx says
who's in it. Cellfie plays Conway's Game of Life on an infinite board, with the rules
of the game as a decision model on [aityx.ai](https://aityx.ai). Every
generation is one call to aityx: the app counts what is on the board
(every distinct situation a cell is in, and every cluster of live cells
with its shape), aityx decides what lives, what dies and what is born, and
names the well-known patterns among the clusters (still lifes, oscillators,
spaceships and methuselahs, as [Wikipedia](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life)
lists them), and the app draws the next board, labels the patterns,
notifies when one appears, and shows every call, request and response,
in a side panel. Conway's rules are on at the start; HighLife's birth with
six neighbours and Life without death can be switched on from **Rules**.
Pick a **Random start** (a sparse, medium or dense soup, islands, a glider
fleet, a zoo with one of each pattern, or a methuselah), press **Play**,
and set the **Acceleration** from half a generation a second to as fast
as aityx answers.

## Technology

| Part | Technology |
|---|---|
| App ([cellfie_app/](cellfie_app)) | [Flutter](https://flutter.dev) (Dart): web, Android, iOS and Linux from one codebase |
| API ([cellfie_api/](cellfie_api)) | Dart (`dart:io`): holds the [aityx](https://aityx.ai) key and runs each generation on aityx |
| Rules | The Life model, [cellfie_api/models/life.json](cellfie_api/models/life.json): a decision table with a why on every row, and the pattern catalogue |
| Dev environment | [Devbox](https://www.jetify.com/devbox) (Nix) on a laptop, or a [Dev Container](https://containers.dev/) from the [published image](../image/), process-compose for the services either way; or [Docker Compose](compose.yaml) |

The toolchain is pinned in [devbox.json](devbox.json) and locked in
[devbox.lock](devbox.lock): Flutter, GNU Make and curl. It is the same
lock as Mortgage Hub's and Contact Hub's, so the three share one Nix
store.

## Run it locally with devbox

1. Install [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/).
2. Put your [aityx](https://aityx.ai) key in `.env` (copy
   [.env.example](.env.example)): the same `AITYX_API_KEY` as Mortgage
   Hub's and Contact Hub's, for instance
   `grep '^AITYX_' ../ContactHub/.env > .env`. Without it the app runs,
   but no generation can.
3. From this folder:

   ```bash
   devbox services up           # add --pcflags "--tui=false" when not in a terminal
   ```

That starts, from [process-compose.yaml](process-compose.yaml):

| URL | What |
|---|---|
| http://localhost:8930/app/ | The app's release build, served by a small native web server ([scripts/flutter-web.sh](scripts/flutter-web.sh)). The first start builds it (about 20 s on a laptop, a minute or two on a 4-core codespace); later starts reuse it until the app changes |
| http://localhost:8931/api/health | The API, compiled to a native executable ([scripts/api.sh](scripts/api.sh)); the web app reaches it as `/api/` on its own origin, through the web server's proxy |

That's what Docker Compose serves too, and it keeps the machine free:
the two servers hold about 35 MB between them. For hot reload while
working on the app, run the Flutter dev server instead, with
`WEB_MODE=debug devbox services up`, or on its own with `devbox run web`
(press `r` in its terminal). `devbox run build` builds the web build and
the executables ahead of time ([scripts/build.sh](scripts/build.sh)),
only what changed.

The ports are 8930 and 8931, so Cellfie runs alongside Mortgage Hub
(8880, 8881) and Contact Hub (8890, 8891). Pick a **Random start** over the cells
in view (soups of three densities, islands, a glider fleet, a zoo with
one of each pattern, the R-pentomino or the acorn), or tap cells to
draw; drag to move around the
infinite board and scroll to zoom. **Play** runs generations at the
**Acceleration** you set, **Step** runs one. Each generation is a call
to aityx, shown in the panel on the right with what it decided and the
JSON both ways (see [Calls panel](specs/calls-panel.md)); patterns aityx
recognizes are named on the board, and a notice says when one appears
(see [Patterns](specs/patterns.md)). **Rules** switches rules on and off
(see [Rules](specs/rules.md)).

Once both are ready, the `health-check` monitor prints where to open the
app (in a codespace, its forwarded URL too), waits 5 s
(`HEALTH_CHECK_DELAY`), then logs one line every 15 s
(`HEALTH_CHECK_INTERVAL`); 🤖 [aityx](https://aityx.ai) is ⚪ when the API
has no key:

```
Cellfie is up. Open the app at:
  http://localhost:8930/app/
Health checks start in 5 s, then every 15 s.
2026-10-23 12:07:31 🌐 Web ✅ · 🔌 API ✅ · 🤖 aityx ✅
```

Stop everything with `devbox services stop`. To run only the app, use
`devbox run web`, the dev server with hot reload (set `FLUTTER_WEB_PORT`
to change the port, `WEB_MODE=release` for the release build); only the
API, `devbox run api` (`API_PORT`).

### The model

[cellfie_api/models/life.json](cellfie_api/models/life.json) is sent
with every generation as the `decision` of `POST /v1/systemone`, with
the board as the `state`. Its `fate` function is the rules, a decision
table where each rule's rows fire only when its switch in `state.rules`
is on; its `identify` function is the pattern catalogue, one row per
phase of each pattern, generated from seeds by
`dart run tool/catalogue.dart` in `cellfie_app/` (`--check` says if it's
out of date); its `kind_of` function says what each pattern is. After
changing it, `bash scripts/model-test.sh` runs it on aityx: all 18
situations against Conway's rules, the other rules, every shape of the
catalogue, and an empty board. See [Generation](specs/generation.md).

### Building the binaries

The [Makefile](Makefile) builds release binaries through
[scripts/make.sh](scripts/make.sh):

```bash
make            # every platform this host can build
make web        # cellfie_app/build/web/
make android    # cellfie_app/build/app/outputs/flutter-apk/app-release.apk
make ios        # cellfie_app/build/ios/iphoneos/Runner.app (macOS, unsigned)
make linux      # cellfie_app/build/linux/<arch>/release/bundle/ (Linux only)
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

and open http://localhost:8930/app/. [compose.yaml](compose.yaml) builds
and starts two services:

| Service | What |
|---|---|
| `web` | The app's release web build ([docker/web.Dockerfile](docker/web.Dockerfile)), served by nginx under `/app/`, with `/api/` proxied to the API ([docker/nginx.conf](docker/nginx.conf)) |
| `api` | The API compiled to a native executable ([cellfie_api/Dockerfile](cellfie_api/Dockerfile)); not published, reached only through `web` |

For the key, copy [.env.example](.env.example) to `.env` and fill in
`AITYX_API_KEY` (or export it); optionally set `AITYX_URL` for another
HTTPS endpoint. Both values go to the API only, never the web app. The first build
takes a few minutes (it downloads Flutter); later ones
reuse Docker's cache. Set `FLUTTER_WEB_PORT` to change the port; the app
is bound to 127.0.0.1 unless you set `CELLFIE_BIND_HOST=0.0.0.0`. Stop
it with `docker compose down`. Both services have health checks, so
`docker compose up --wait` returns once they are healthy. There is no hot
reload: rebuild after a change.

## Run it in a codespace

[![Open Cellfie in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FCellfie%2Fdevcontainer.json&machine=standardLinux32gb)

That link opens this repository's **Cellfie** dev container on a
4-core machine (16 GB RAM), which is what the Flutter builds want.
To choose for yourself instead, use *Code → Codespaces → New with
options* and pick **Cellfie** as the dev container configuration —
the repository holds several samples, so the configuration matters.

The codespace uses your [aityx](https://aityx.ai) key, the same
`AITYX_API_KEY` Codespaces secret as Mortgage Hub's and Contact Hub's.
The optional `AITYX_URL` secret selects a non-default HTTPS endpoint;
otherwise the API uses `https://api.aityx.ai`. Both settings are passed
only to the API process, never to Flutter or the web service.
GitHub keeps Codespaces secrets per user and grants them per repository,
so if your key already reaches this repository, there is nothing to do.
Otherwise add it at
[github.com/settings/codespaces](https://github.com/settings/codespaces)
(**New secret**, name `AITYX_API_KEY`, access to
`aletyx/samples-and-demos`), or enter it when GitHub asks on the creation
page. Without it the app runs, but no generation can.

When the codespace is created,
[on-create.sh](../.devcontainer/Cellfie/on-create.sh) copies the app's
release web build from the [published image](../image/) into this
folder (unless the app changed since the image was made: then it builds
itself, a minute or two),
[update-content.sh](../.devcontainer/Cellfie/update-content.sh)
compiles the API and the web server (a few seconds) and
[post-create.sh](../.devcontainer/Cellfie/post-create.sh) says whether
your key arrived. Then, on that and every later start,
[post-start.sh](../.devcontainer/Cellfie/post-start.sh) starts the
services in the background and makes port **8930** public. There is
nothing to run: the codespace is available about three minutes after
you ask for it and the app answers within a minute after that; open
port 8930 from the **Ports** panel (Codespaces may open it in a browser
tab for you). Its bare URL redirects to the app at `/app/`.

Watch the services with `process-compose attach -U -u
/tmp/aityx-demos-Cellfie.sock`, stop them with `./stop-all.sh Cellfie`
from the repository root (or `process-compose down -U -u` with the same
socket), and start them again with `./start-all.sh Cellfie`. There is
no devbox in a codespace: the demos run on the image's own Flutter and
process-compose (`DEMOS_TOOLCHAIN=image`, see
[demos-toolchain.sh](../demos-toolchain.sh)); `devbox services` is for
a laptop.

**If the app doesn't start, send us `Cellfie/startup.log`.** Every
step of the codespace's start goes there, timestamped, including a line
saying when the web app and the API first answered. It holds no secrets.

**Check the port's visibility.** In the **Ports** panel, the
*Visibility* column for 8930 should say **Public**. If it says
**Private**, right-click the port, choose **Port Visibility → Public**
and reload the app.

## Run it in a dev container locally

Open the repository root in VS Code and choose **Reopen in Container**,
then **Cellfie**. The dev container lives at the root of the
repository, in [.devcontainer/Cellfie/](../.devcontainer/Cellfie),
because that is where GitHub looks for one. It runs the same
[published image](../image/) as every dev container here,
`docker.io/aletyxcode/samples-and-demos-devcontainer`, built from one
[Containerfile](../image/Containerfile): Microsoft's `ubuntu-24.04`
base with pinned, checksum-verified Flutter, process-compose and the
GitHub CLI, and every demo's release web build.

## Contributing

1. Create a branch from an up-to-date `main`.
2. Make one change per pull request, with its tests. Run `flutter analyze`
   and `flutter test` in `cellfie_app/`, and `dart analyze` and
   `dart test` in `cellfie_api/`. After changing the model, `bash
   scripts/model-test.sh` runs it on aityx; after changing the pattern
   seeds, `dart run tool/catalogue.dart` in `cellfie_app/` rewrites the
   catalogue.
3. Update the matching feature spec in [specs/](specs/) and add an entry to
   [specs/requests.md](specs/requests.md).
4. Open a pull request against `main`.

## Learn more

- [specs/](specs/README.md): the specification of every feature.

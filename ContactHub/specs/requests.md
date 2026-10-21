# Requests

The requests that shaped Contact Hub, oldest first, each with what changed.
The feature files hold the current specification; see the
[index](README.md).

## 2026-10-21

1. **Start Contact Hub, a new sample in this repository, following
   Mortgage Hub's standards and patterns: an app where someone can ask
   anything and it's routed to the right department or person, with
   validations. For now a static index page and a hello-world page, with
   a dev container and a devbox configuration, so the scaffolding can be
   launched and tested in a codespace and on a local machine.** Added
   `ContactHub/`: the Flutter app (`contacthub_app`, web, Android, iOS and
   Linux) with a [welcome page](welcome.md) and a [Hello page](hello.md)
   that shows the API's greeting; a Dart API (`contacthub_api`) with
   `/api/hello` and `/api/health`; devbox, process-compose and the health
   monitor, the Makefile, Docker Compose, and the dev container in
   `.devcontainer/ContactHub/`, all as Mortgage Hub has them (see
   [Development environment](dev-environment.md)). Ports 8890 and 8891,
   so it runs alongside Mortgage Hub. The [theme](theme.md) is the aityx
   palette. No aityx key yet: nothing calls aityx.
2. **Use the same aityx key as Mortgage Hub, copied from our GitHub.**
   GitHub never returns a secret's value, so the key can't be copied, and
   it doesn't need to be: Codespaces secrets belong to a user and are
   granted per repository, and Contact Hub is in the same repository. The
   dev container now declares the same `AITYX_API_KEY` secret, so a key
   already granted to this repository for Mortgage Hub reaches it.
   `post-create.sh` and the start-up log say whether it arrived; the API
   reads `AITYX_API_KEY` and `AITYX_URL` (from the environment, else
   `.env`; see `.env.example`), Docker Compose passes them to the API
   only, and `/api/health` and the health monitor's 🤖 aityx say whether
   the key is set. Nothing calls aityx yet. See
   [Development environment](dev-environment.md).
3. **Generate a cool icon.** An orange speech bubble with a route cut
   into it that branches three ways, the chosen branch lit white, in the
   aityx palette; generated for web, Android and iOS from SVG masters with
   `flutter_launcher_icons`, as Mortgage Hub's. See
   [App icon](app-icon.md).
4. **When the health check starts, print the address to access the app,
   then wait about 5 seconds before checking.** The health monitor now
   prints `http://localhost:8890/app/` and, in a codespace, the forwarded
   URL, then waits `HEALTH_CHECK_DELAY` (5 s) before its first check. See
   [Development environment](dev-environment.md).

## 2026-10-21 (later)

5. **Add a text box where the user types their request, with a recording
   icon beside it to dictate it; run efficient voice recognition in the
   browser, client-side if possible, and process the request later.**
   The welcome page now has the [request box](request.md): **Your
   request**, a microphone button beside it, a status line and **Send**,
   which for now only confirms the request was received. Speech is
   recognized on the device only: the Web Speech API with
   `processLocally = true` where the browser has it (Chrome, Edge),
   installing the language pack on first use, with words appearing live;
   else Moonshine tiny, run by transformers.js 4.3.1 in a Web Worker on
   WebGPU or WASM, transcribing when you stop. The server-based Web Speech
   mode is never used. **Say hello** became a link under the box. No voice
   input in the Android, iOS and Linux apps yet.

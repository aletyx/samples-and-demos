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

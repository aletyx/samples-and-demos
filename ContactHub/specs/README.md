# Contact Hub — software specification

The current specification of the product, one file per feature. Update the
feature files a request changes, and add a file when a request adds a
feature. [requests.md](requests.md) holds the history of requests that shaped
it.

## Product

Contact Hub lets someone ask anything and routes the question to the
right department or person, running the checks it needs on the way. For
now it is a welcome page where a request can be typed or dictated, on
the device. Nothing processes the request yet.

## Features

**App**

- [Welcome page](welcome.md): the app's home, with its name, a one-line
  welcome, the request box and the build's version.
- [Request box](request.md): the request, typed or dictated with the
  microphone beside the field, and **Send**. Speech is recognized in the
  browser only: Chrome's and Edge's on-device Web Speech, else Moonshine
  tiny run by transformers.js in a Web Worker.
- [Theme](theme.md): the aityx dark palette.
- [App icon](app-icon.md): an orange speech bubble with a route that
  branches three ways, the chosen branch lit; the favicon and every
  platform's icon, generated from SVG masters.

**Backend**

- [API](api.md): `contacthub_api`, a Dart server that holds the aityx key
  and, for now, serves only `GET /api/health`.

**Project**

- [Development environment](dev-environment.md): devbox, process-compose,
  the health monitor, the builds, Docker Compose and the dev container.

## Workflow

- Every new feature or bug fix starts on a new branch from `main`, with its
  own pull request. Nothing is pushed directly to `main`. See
  [CLAUDE.md](../CLAUDE.md).
- Every request updates the affected feature specs and the
  [request log](requests.md) in the same PR.
- Each feature file ends with its own **Known limitations**, where it has
  any.

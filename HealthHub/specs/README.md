# HealthHub — software specification

The current specification of the product, one file per feature. Update the
feature files a request changes, and add a file when a request adds a
feature. [requests.md](requests.md) holds the history of requests that shaped
it.

## Product

HealthHub is a demo built like Mortgage Hub, Contact Hub and PokerFace,
with one more part: a PostgreSQL database. For now it is a hello world
that proves the whole path: the app asks the API, the API reads the
greeting from the database, and the app shows it with where it came from
and the health of each part. What HealthHub does, and what aityx decides
in it, is still to be specified.

## Features

**App**

- [Welcome](welcome.md): the one screen, the greeting from the database
  with the health chips and the version.
- [Theme](theme.md): the aityx dark palette.

**Backend**

- [API](api.md): `healthhub_api`, a Dart server that holds the aityx key,
  talks to PostgreSQL and serves `GET /api/hello` and `GET /api/health`.
- [Database](database.md): PostgreSQL as a container, the `healthhub`
  database and user, the `greetings` table the API makes.

**Project**

- [Development environment](dev-environment.md): devbox, process-compose,
  Docker for the database, the health monitor, the builds, Docker Compose
  and the dev container.

## Workflow

- Every new feature or bug fix starts on a new branch from `main`, with its
  own pull request. Nothing is pushed directly to `main`. See
  [CLAUDE.md](../CLAUDE.md).
- Every request updates the affected feature specs and the
  [request log](requests.md) in the same PR.
- Each feature file ends with its own **Known limitations**, where it has
  any.

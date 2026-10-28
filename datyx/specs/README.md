# datyx: software specification

The current specification of the system, one file per feature. Update the
feature files a request changes, and add a file when a request adds a
feature. [requests.md](requests.md) holds the history of requests that shaped
it.

## Product

datyx is a system built around data: a Quarkus REST API on GraalVM, its
PostgreSQL database and an OpenMetadata server as the catalogue. Data and
logic live in the API; its views are the datyx dashboard, a Flutter app in
a folder of its own ([../../datyx-dashboard/](../../datyx-dashboard/),
specified there), which only asks and shows. The API, the dashboard and
HealthHub are the datyx group, started and stopped together. The stack
starts with one command; the API answers hello and its status, keeps the
data sources users add, and authenticates users with Google through
OpenID Connect, an identity HealthHub passes on unchanged.

## Features

- [The API](api.md): the Quarkus app, its endpoints, its entities and the
  components it is built from.
- [Data sources](data-sources.md): the first entity, databases, S3
  buckets and folders with their access details, added and removed.
- [Authentication](auth.md): OpenID Connect with Google, who is calling,
  what is secured, and HealthHub's tokens accepted too.
- [Development environment](dev-environment.md): devbox, process-compose,
  Docker Compose, the ports, the settings, the version and the build.

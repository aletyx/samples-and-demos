# The dashboard

The datyx dashboard is a Flutter web app in `datyx_dashboard/` (package
`datyx_dashboard`), in the aityx dark palette like every demo's app. It
invokes the datyx API ([../../datyx/specs/api.md](../../datyx/specs/api.md))
and shows what it answers, with the details of each call. It computes,
stores and decides nothing on its own: when a view needs data the API
doesn't have, the API gets it first.

## What it shows

One screen, `DashboardScreen`:

- Status cards, from `GET /api/status`, refreshed every 15 s and on the
  refresh button: API (name and version, uptime, started at), PostgreSQL
  (version, or the error), OpenMetadata (version and URL, or the error),
  Sign-in (off, with no `OIDC_CLIENT_ID` on the API; on and nobody signed
  in; or the issuer and whom the API sees, from `GET /api/me`), Records
  (how many data sources and greetings). A green dot when the part is
  ok, red otherwise. A line in red when the API itself didn't answer.
- Data sources (`DataSourcesCard`): the list from `GET /api/datasources`,
  newest first, one row each with the kind's icon, the name and kind,
  where it points on one line (`engine://host:port/database as user`,
  `s3://bucket/prefix (region) at endpoint`, or the path), the
  description, when and by whom it was added, and a remove button, which
  confirms and then `DELETE`s. An Add button opens `AddDataSourceDialog`:
  the kind (Database, S3 bucket, Filesystem), name and description, then
  the fields of that kind (engine and port, host, database, username and
  password; bucket, region and prefix, endpoint, access key id and secret
  access key; or the path), the required ones checked before the `POST`;
  secrets go as typed, the rest trimmed.
  Errors the API answers show in a snack bar. With authentication on and
  nobody signed in, the card says to sign in and the list isn't asked.
- Hello: a name field and a button; `GET /api/hello` with the name, the
  message shown under it.
- Greetings on record: the list from `GET /api/greetings`, newest first,
  with id, message and time; a field and a button to `POST /api/greetings`
  a new one, then refresh. An error is shown in a snack bar.
- API calls: a side panel (420 px wide, on the right from 1000 px; a
  280 px panel at the bottom on narrower screens) with every call made,
  newest first, up to 100: method, path with its query, status (or
  pending, or error), time of day and duration; expanded, the request and
  the response bodies pretty-printed. A button clears it.
- The app bar: the title, the account corner (`UserMenu`: nothing while
  the API has authentication off; Google's own sign-in button while
  nobody is signed in; the user's picture, name, email and a sign-out
  button once someone is), the dashboard's version when built by the
  scripts, the refresh button.

## Sign-in

`AuthController` (`lib/auth/auth_controller.dart`) takes the API's
`GET /api/auth/config` at start, asked again with a growing delay (3 s
up to 30 s) while the API doesn't answer, so a dashboard opened before
the API is up still gets its sign-in. Off: nothing happens and every call goes
out anonymous. On: it initializes `google_sign_in` with the client id the
API published (nothing is built in), listens to its sign-in and sign-out
events, and tries a silent sign-in from a previous session. The web
renders Google's own button (`google_sign_in_web`'s `renderButton`, in
`sign_in_button_web.dart`, chosen by a conditional import); other
platforms get a button of ours that calls `authenticate()`. The signed-in
account's ID token (an OpenID Connect token, audience the client id) is
what `HttpDatyxApi` sends as `Authorization: Bearer` on every call; after
a 401 it asks for a silent re-sign-in once and retries, since Google's
tokens live an hour. Signing in or out refreshes the screen.

## The API client

`DatyxApi` (`lib/api/datyx_api.dart`): `authConfig()`, `me()`,
`status()`, `hello(name)`, `greetings(limit)`, `addGreeting(message)`,
`dataSources(limit)`, `addDataSource(NewDataSource)`,
`removeDataSource(id)`, and the `CallLog` the panel listens to.
`HttpDatyxApi` is the real one, over `package:http`, with a token
provider for the bearer and one for a refresh after a 401, a 20 s timeout
on every call, and request bodies logged with their secrets (`password`,
`secretAccessKey`) replaced by dots; `API_BASE_URL`
at build time is the API's base, empty meaning the app's own origin, so
the app calls `/api/...` and whatever serves it proxies that to the API.
A non-2xx answer or a failed call throws `ApiException`. `DataSource`
keeps the access details as the API answers them (a map under the
type's key, secrets replaced by `passwordSet` and `secretAccessKeySet`)
and summarizes them on one line; `NewDataSource` is the `POST` body.

## Serving

Under `/app/` (base href), with `/api/` and `/q/` reaching the API on the
same origin, so there's no CORS and a forwarded port works:

- `scripts/flutter-web.sh` in release mode (`devbox services up`): the
  release build, served by `bin/web_server.dart` (`lib/web_server.dart`,
  dart:io only) compiled to `build/web_server`: files under `/app/` with
  `index.html` as the fallback, `/api/` and `/q/` proxied to
  `DATYX_API_URL`, `/` redirected to `/app/`.
- `scripts/flutter-web.sh` in debug mode (`devbox run web`): Flutter's dev
  server on the web-server device with hot reload, its proxy generated in
  `web_dev_config.yaml` (git-ignored).
- Docker Compose: nginx (`docker/nginx.conf.template`) with the same
  shape, `DATYX_API_URL` filled in when the container starts.

Web is the only platform so far; `flutter create --platforms <name> .`
adds another, and `scripts/make.sh` a target for it.

## Tests

`flutter test` in `datyx_dashboard/`: a `FakeDatyxApi` answers from
memory with authentication off; the status cards show its values, hello
by name answers and is logged in the panel, a greeting added appears in
the list and the count, and a filesystem data source added through the
dialog appears with its path and author, is counted, and is gone after
the remove button and its confirmation.

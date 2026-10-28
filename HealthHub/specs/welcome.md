# Welcome

The app's one screen so far
([welcome_screen.dart](../healthhub_app/lib/welcome_screen.dart)), under
an app bar titled **HealthHub** with the account corner and a refresh
button: two cards, at most 560 px wide, centred on the page.

When it opens, and on every refresh, the app asks the API
([health_hub_api.dart](../healthhub_app/lib/api/health_hub_api.dart))
for `GET /api/health` and then `GET /api/hello`, and the card shows:

- **While waiting**: an hourglass, "Asking the API…", and a line saying
  the greeting comes from PostgreSQL through the API.
- **The greeting**: a heart in the aityx orange, the message as the title
  (**Hello, world**), and a line saying what it was read from
  (`PostgreSQL 17.6`, the first two words of the server's `version()`)
  through the API and since when (the row's `created_at`, in local time
  as `YYYY-MM-DD HH:MM`). With a signed-in user the title is the API's
  **Hello, <name>**. Under it four chips, each a dot and a label:
  **API ok**, **PostgreSQL ok** (green) or **down** (red), **aityx
  key ok** (green) or **not set** (gray: missing, but nothing is broken),
  and **signed in as <name>** (green), **sign-in nobody** (red, when the
  API wants a user) or **sign-in off** (gray).
- **When the API or its database doesn't answer**: a crossed cloud in
  red, "No greeting", the error (for instance `HTTP 503: the database is
  not answering`), and how to start the services.

The second card, **datyx**, asks the API for `GET /api/datyx/me` and
`GET /api/datyx/datasources`, which it forwards to the datyx API with the
user's own token: "datyx sees you as <email>" and how many data sources
datyx has on record (green); "datyx answers anonymously" while
authentication is off there; a lock and "Sign in to reach datyx as
yourself" on a 401; a crossed cloud and the error when datyx doesn't
answer.

The account corner: nothing while the API has authentication off;
Google's own sign-in button while nobody is signed in; the user's picture,
name and a sign-out button once someone is. `AuthController`
([lib/auth/](../healthhub_app/lib/auth/)) reads `GET /api/auth/config`
at start (asked again, 3 s then up to 30 s apart, while the API doesn't
answer), initializes `google_sign_in` with the client id the API
publishes, tries a silent sign-in, and hands the ID token to the API
client, which sends it as a bearer on every call and retries once with a
fresh one after a 401. Signing in or out asks everything again.

At the bottom, when the build has one, the version: `HealthHub X.Y.Z`
(the `HEALTHHUB_VERSION` dart-define, see [Development
environment](dev-environment.md)).

## Known limitations

- Just the hello world: what HealthHub does comes next.
- The app's icons are Flutter's defaults; an app icon spec will replace
  them.

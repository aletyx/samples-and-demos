# Hello page

The scaffolding check: one page that shows the app runs and reaches its
API.

## App

[HelloScreen](../contacthub_app/lib/hello/hello_screen.dart), titled
**Hello** in its app bar, centered and at most 480 px wide:

- **Hello, world!**, bold, from the app itself;
- below it, the API's greeting: a spinner while it loads, then the
  message with a check icon (secondary color), or, when the call fails,
  the reason with an error icon (error color) and a **Try again** button.

[ApiGreeter](../contacthub_app/lib/hello/greeting.dart) fetches
`GET /api/hello` at `API_BASE_URL` (a dart-define; empty means the app's
own origin, through the dev server's or nginx's `/api/` proxy), with a
10 s timeout. It fails with "The API did not answer.", "The API answered
HTTP <status>." or "The API answered without a greeting." Tests pass
their own `Greeter`.

## API

[contacthub_api](../contacthub_api/bin/server.dart), routes in
[lib/routes.dart](../contacthub_api/lib/routes.dart):

| Request | Answer |
|---|---|
| `GET /` | 302 to `/app/`, so a forwarded port's bare URL opens the app |
| `GET /api/health` | `{"ok": true, "aityx": <whether the API has its key>}` |
| `GET /api/hello` | `{"message": "Hello from Contact Hub's API"}` |
| `OPTIONS` anything | 204 |
| anything else | 404 `{"error": "not found"}` |

The API reads `AITYX_API_KEY` and `AITYX_URL` (default
`https://api.aityx.ai`, which must be https) from its environment;
`scripts/api.sh` falls back to `.env`. Nothing calls aityx yet.

CORS allows `ALLOWED_ORIGINS` (by default the dev server's,
`http://localhost:8890` and `http://127.0.0.1:8890`). `server
healthcheck` asks a running server's `/api/health` and exits 0 when it
answers ok; it's the Docker health check.

## Known limitations

- The greeting is fixed text; nothing is asked or routed yet.

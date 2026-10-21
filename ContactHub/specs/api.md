# API

[contacthub_api](../contacthub_api/bin/server.dart), a Dart server that
holds the aityx key, which must never reach the app; routing will run
through it. Routes in [lib/routes.dart](../contacthub_api/lib/routes.dart):

| Request | Answer |
|---|---|
| `GET /` | 302 to `/app/`, so a forwarded port's bare URL opens the app |
| `GET /api/health` | `{"ok": true, "aityx": <whether the API has its key>}` |
| `OPTIONS` anything | 204 |
| anything else | 404 `{"error": "not found"}` |

The API reads `AITYX_API_KEY` and `AITYX_URL` (default
`https://api.aityx.ai`, which must be https) from its environment;
`scripts/api.sh` falls back to `.env`. Nothing calls aityx yet.

CORS allows `ALLOWED_ORIGINS` (by default the dev server's,
`http://localhost:8890` and `http://127.0.0.1:8890`). `server
healthcheck` asks a running server's `/api/health` and exits 0 when it
answers ok; it's the Docker health check.

The app doesn't call the API yet. When it does, it will reach it at
`API_BASE_URL` (a dart-define; empty means the app's own origin, through
the dev server's or nginx's `/api/` proxy).

## Known limitations

- Only the health check: nothing is routed yet.

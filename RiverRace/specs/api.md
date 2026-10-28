# API

[riverrace_api](../riverrace_api/bin/server.dart), a Dart server that holds
the aityx key, which must never reach the app, and asks aityx what the
aityx pilots do ([Decisions](decisions.md)). Routes in
[lib/routes.dart](../riverrace_api/lib/routes.dart) and
[bin/server.dart](../riverrace_api/bin/server.dart):

| Request | Answer |
|---|---|
| `GET /` | 302 to `/app/`, so a forwarded port's bare URL opens the app |
| `GET /api/health` | `{"ok": true, "aityx": <whether the API has its key>}` |
| `POST /api/decide` | `{"tick": 120, "pilots": [{"id": "p1", "name": "Careful", "rules": [...], "sense": {...}}, ...]}` → `{"tick": 120, "actions": {"p1": {"steer", "throttle", "fire", "rule", "why"}, ...}, "aityx": {"request", "response", "took_ms"}}` |
| `OPTIONS` anything | 204 |
| anything else | 404 `{"error": "not found"}` |

The API reads `AITYX_API_KEY` and `AITYX_URL` (default
`https://api.aityx.ai`, which must be https) from its environment;
`scripts/api.sh` falls back to `.env`.

A rule is `{"when": {sensor: cell}, "then": {"steer": ..., "throttle":
..., "fire": true|false}, "why": ...}`; cells that are empty or `-` are
left out, and commands left out are `straight`, `normal` and `false`.
`POST /api/decide` ([lib/strategy.dart](../riverrace_api/lib/strategy.dart))
refuses, with 400 and `{"error": ...}`, a body over 64 KB, invalid JSON, a
`tick` that isn't a whole number, other than one or two pilots, a pilot
id other than `p1` or `p2` or a repeated one, more than 40 rules, an
unknown sensor or command value, a `fire` that isn't a boolean, a text
over 200 characters, and a `sense` missing a sensor or with a value of
the wrong kind; without a key it answers 503. It sends the model to aityx
with a 30 s timeout (504 when it runs out); when aityx answers an error it
answers 502 with aityx's messages under `problems` (a cell aityx can't
read, for instance), and 502 when the answer has no actions. `aityx` is
left out if aityx's answer contains the key. The Docker image carries the
model in `/app/models`.

CORS allows `ALLOWED_ORIGINS` (by default the web server's,
`http://localhost:8940` and `http://127.0.0.1:8940`). `server
healthcheck` asks a running server's `/api/health` and exits 0 when it
answers ok; it's the Docker health check.

The app reaches the API at `API_BASE_URL` (a dart-define; empty means
the app's own origin, through the web server's or nginx's `/api/`
proxy).

## Known limitations

- One call per decision; nothing is cached or stored.

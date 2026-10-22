# API

[contacthub_api](../contacthub_api/bin/server.dart), a Dart server that
holds the aityx key, which must never reach the app, and routes requests
in two calls: the local model on Ollama reads the message ([Reading with
a local model](reading.md)), then aityx decides ([Routing](routing.md)).
Routes in [lib/routes.dart](../contacthub_api/lib/routes.dart) and
[bin/server.dart](../contacthub_api/bin/server.dart):

| Request | Answer |
|---|---|
| `GET /` | 302 to `/app/`, so a forwarded port's bare URL opens the app |
| `GET /api/health` | `{"ok": true, "aityx": <whether the API has its key>, "local_model": {"name": "qwen3:1.7b", "ready": <whether Ollama answers and lists it>}}` |
| `POST /api/route` | `{"message": "..."}` → `{"routing": {...}, "reading": {"request", "response"}, "aityx": {"request", "response"}}` |
| `OPTIONS` anything | 204 |
| anything else | 404 `{"error": "not found"}` |

The API reads from its environment `AITYX_API_KEY`, `AITYX_URL` (default
`https://api.aityx.ai`, which must be https), `OLLAMA_URL` (default
`http://127.0.0.1:11434`, http or https) and `OLLAMA_MODEL` (default
`qwen3:1.7b`); `scripts/api.sh` falls back to `.env`. `/api/health`
looks at Ollama's `/api/tags` at most every 10 s (a name without a tag
means `:latest`, as Ollama's does).

`POST /api/route` refuses, with 400 and `{"error": ...}`, a body over
16 KB, invalid JSON, or a `message` that's missing, empty or over 2000
characters; without a key it answers 503. It then:

1. **Reads** on Ollama's `POST /api/chat`, with a 120 s deadline (504
   when it runs out): 503 when Ollama isn't running (`the local model is
   not running: start Ollama at ... and pull ...`) or answers 404 (the
   model isn't pulled); 502 when it answers another error, or an answer
   that isn't JSON or doesn't fit the schema (`the local model could not
   read it: ...`).
2. **Decides** on aityx's `POST /v1/systemone`, with a 90 s deadline
   (504), and answers 502 when aityx answers an error, a `decision_error`
   or no routing.

`routing` holds the department (`id`, `name`, `person`, `role`,
`email`), `reason` and `department_rule`, `priority`, `priority_reason`
and `priority_rule`, `response_hours`, `needs_review`, `topic` (`choice`,
`confidence`, as the local model read them), `request_kind`, `checks`
(`id`, `label`, `flagged`, `probability`: the local model's) and `policy`
(`request_kind`, `resolution`, `reason`, `resolution_rule`,
`refund_amount`, `amount_reason`, `amount_rule`, `refund_by`,
`days_since_order`, `days_since_delivery`, `order`, `order_number`; see
[Order policy](order-policy.md)). `reading` is the body sent to Ollama
and its answer as it came. `aityx` is the body sent to aityx (the
`decision` and the `state`: the `message`, the six facts read, `today`
in UTC and the `order` from the order book) and its answer; it is left
out if aityx's answer contains the key. The Docker image carries the
model in `/app/models`.

CORS allows `ALLOWED_ORIGINS` (by default the dev server's,
`http://localhost:8890` and `http://127.0.0.1:8890`). `server
healthcheck` asks a running server's `/api/health` and exits 0 when it
answers ok; it's the Docker health check.

The app reaches the API at `API_BASE_URL` (a dart-define; empty means
the app's own origin, through the dev server's or nginx's `/api/`
proxy).

## Known limitations

- One reading and one decision per request, in sequence; nothing is
  cached or stored.

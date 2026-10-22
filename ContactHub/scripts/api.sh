#!/usr/bin/env bash
# Runs the API (contacthub_api/) on http://localhost:${API_PORT:-8891}.
# Runs via `devbox services up` (see process-compose.yaml) or `devbox run api`.
# The aityx and Ollama settings come from the environment, else the repo's
# .env (see .env.example). They're exported to the server's own environment
# only: never on a command line, and never to the Flutter app.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
for name in AITYX_API_KEY AITYX_URL OLLAMA_URL OLLAMA_MODEL; do
  if [[ -z "${!name:-}" && -f "$root/.env" ]]; then
    value="$(sed -n "s/^${name}=//p" "$root/.env" | tail -1)"
    [[ -n "$value" ]] && export "$name=$value"
  fi
done
unset value
export API_PORT="${API_PORT:-8891}"
export ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-http://localhost:${FLUTTER_WEB_PORT:-8890},http://127.0.0.1:${FLUTTER_WEB_PORT:-8890}}"

cd "$root/contacthub_api"
dart pub get >/dev/null
exec dart run bin/server.dart

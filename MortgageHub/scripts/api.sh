#!/usr/bin/env bash
# Runs the API (mortgagehub_api/) on http://localhost:${API_PORT:-8881}:
# bin/server.dart compiled to a native executable (scripts/build.sh, only
# when the API changed), so it starts at once and stays small.
# Runs via `devbox services up` (see process-compose.yaml) or `devbox run api`.
# The aityx settings come from the environment, else the repo's .env (see
# .env.example). They're exported to the server's own environment only:
# never on a command line, and never to the Flutter app.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
for name in AITYX_API_KEY AITYX_URL ASSUMED_RATE; do
  if [[ -z "${!name:-}" && -f "$root/.env" ]]; then
    value="$(sed -n "s/^${name}=//p" "$root/.env" | tail -1)"
    [[ -n "$value" ]] && export "$name=$value"
  fi
done
unset value
export API_PORT="${API_PORT:-8881}"
export ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-http://localhost:${FLUTTER_WEB_PORT:-8880},http://127.0.0.1:${FLUTTER_WEB_PORT:-8880}}"

bash "$root/scripts/build.sh" api
# The server finds its model beside its binary: build/../models/.
exec "$root/mortgagehub_api/build/server"

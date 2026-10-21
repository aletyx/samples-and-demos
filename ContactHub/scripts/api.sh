#!/usr/bin/env bash
# Runs the API (contacthub_api/) on http://localhost:${API_PORT:-8891}.
# Runs via `devbox services up` (see process-compose.yaml) or `devbox run api`.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export API_PORT="${API_PORT:-8891}"
export ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-http://localhost:${FLUTTER_WEB_PORT:-8890},http://127.0.0.1:${FLUTTER_WEB_PORT:-8890}}"

cd "$root/contacthub_api"
dart pub get >/dev/null
exec dart run bin/server.dart

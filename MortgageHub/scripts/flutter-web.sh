#!/usr/bin/env bash
# Serves the Flutter app in web mode on http://localhost:${FLUTTER_WEB_PORT}/app/.
# The app lives under /app/, leaving the site root free for other pages.
# Runs via `devbox services up` (see process-compose.yaml) or `devbox run web`.
# Uses the web-server device, so no Chrome is needed; open the URL in any browser.
set -euo pipefail

PORT="${FLUTTER_WEB_PORT:-8880}"
# 127.0.0.1, not localhost: Dart binds "localhost" to IPv6 [::1] only. The
# dev container sets MORTGAGEHUB_BIND_HOST=0.0.0.0, so its forwarded port
# reaches the server. Browsers still reach it at http://localhost:$PORT/app/.
HOST="${MORTGAGEHUB_BIND_HOST:-127.0.0.1}"

cd "$(dirname "$0")/../mortgagehub_app"
source ../scripts/version.sh
flutter pub get
# The welcome screen shows X.Y.Z, Z being when this server started.
# API_BASE_URL: the local API (scripts/api.sh), which runs the regulatory
# check. Public: the aityx key stays in the API.
exec flutter run -d web-server --web-hostname "$HOST" --web-port "$PORT" \
  --base-href /app/ \
  --dart-define="MORTGAGEHUB_VERSION=$VERSION" \
  --dart-define="API_BASE_URL=${API_BASE_URL:-http://localhost:${API_PORT:-8881}}"

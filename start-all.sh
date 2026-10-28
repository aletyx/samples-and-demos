#!/usr/bin/env bash
# Starts every demo that runs as services: each folder with a devbox.json
# and a process-compose.yaml (Mortgage Hub, Contact Hub, ..., and the index
# page in Index/), detached, with `devbox services up -b` (or, in a
# codespace, the image's process-compose: see demos-toolchain.sh), then
# waits until each one's web app and
# API answer and prints where to open them. A demo whose web port already
# answers (started by hand, or with Docker Compose) is left as it is.
#
#   ./start-all.sh              # every demo
#   ./start-all.sh ContactHub   # only these
#   WAIT=0 ./start-all.sh       # start, don't wait
#
# Each demo's aityx settings go in its own .env (see <demo>/.env.example):
# AITYX_API_KEY, the key, and AITYX_URL, the endpoint (https://api.aityx.ai
# unless set; a stage key needs https://api-stage.aityx.ai). Without a key
# the app runs, but it can't call aityx. Each demo serves its app's
# release build and a compiled API (see <demo>/scripts/build.sh); a demo
# whose build is missing or older than its sources builds it first, a
# minute or two, one demo at a time. ./build-all.sh does that ahead, with
# each build's output. Watch one with `devbox services attach -c <demo>`.
# Stop them with ./stop-all.sh.
set -uo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
# How services run: devbox (a laptop) or the dev container image's own
# Flutter and process-compose (DEMOS_TOOLCHAIN=image, a codespace).
# shellcheck source=demos-toolchain.sh
source "$root/demos-toolchain.sh"
# These Codespaces secrets are inherited by each API process. Empty values
# leave the per-demo .env fallback available for local development.
export AITYX_API_KEY="${AITYX_API_KEY:-}"
export AITYX_URL="${AITYX_URL:-}"

if [[ -z "$AITYX_API_KEY" ]]; then
  echo "AITYX_API_KEY is not set; apps will start, but aityx-backed features won't work." >&2
fi

# How long to wait for the demos to answer, in seconds (0: don't wait).
WAIT="${WAIT:-600}"

# demos [names...]: the demos to act on, as folder names: the ones named,
# else every folder with a devbox.json and a process-compose.yaml.
demos() {
  if [[ $# -gt 0 ]]; then
    printf '%s\n' "$@"
    return
  fi
  for config in "$root"/*/devbox.json; do
    dir="$(dirname "$config")"
    [[ -f "$dir/process-compose.yaml" ]] && basename "$dir"
  done
}

# port <demo> <VARIABLE>: the environment override, else the demo's
# process-compose.yaml default for FLUTTER_WEB_PORT or API_PORT.
port() {
  local variable="$2"
  local override="${!variable:-}"
  if [[ -n "$override" ]]; then
    printf '%s\n' "$override"
    return
  fi
  sed -n "s/.*\${$2:-\([0-9]*\)}.*/\1/p" "$root/$1/process-compose.yaml" | head -1
}

# answers <url>: whether the URL answers 2xx.
answers() {
  curl -fs -o /dev/null --max-time 3 "$1"
}

started=()
failed=0
for demo in $(demos "$@"); do
  dir="$root/$demo"
  if [[ ! -f "$dir/devbox.json" || ! -f "$dir/process-compose.yaml" ]]; then
    echo "✗ $demo: no devbox.json and process-compose.yaml in $dir" >&2
    failed=1
    continue
  fi
  web="$(port "$demo" FLUTTER_WEB_PORT)"
  if [[ -n "$web" ]] && answers "http://localhost:$web/app/"; then
    echo "· $demo already answers at http://localhost:$web/app/: left as it is"
    continue
  fi
  echo "▶ $demo: starting ($DEMOS_TOOLCHAIN services, in $dir)"
  if services_up "$dir"; then
    started+=("$demo")
  else
    echo "✗ $demo: starting its services failed; see $(services_attach_hint "$dir")" >&2
    failed=1
  fi
done

if [[ ${#started[@]} -eq 0 ]]; then
  echo "Nothing started."
  exit $failed
fi

if [[ "$WAIT" -le 0 ]]; then
  echo "Started: ${started[*]}. Not waiting; check them with ./start-all.sh later."
  exit $failed
fi

echo "Waiting up to $WAIT s for ${started[*]} to answer (a first start builds the app)..."
deadline=$((SECONDS + WAIT))
pending=("${started[@]}")
while [[ ${#pending[@]} -gt 0 && $SECONDS -lt $deadline ]]; do
  sleep 5
  still=()
  for demo in "${pending[@]}"; do
    web="$(port "$demo" FLUTTER_WEB_PORT)"
    api="$(port "$demo" API_PORT)"
    # The API through the app's origin: the dev server proxies /api/ to it.
    if answers "http://localhost:$web/app/" && answers "http://localhost:$web/api/health"; then
      echo "✅ $demo is up: http://localhost:$web/app/ (API: http://localhost:$api/api/health)"
    else
      still+=("$demo")
    fi
  done
  pending=("${still[@]+"${still[@]}"}")
done

for demo in "${pending[@]+"${pending[@]}"}"; do
  web="$(port "$demo" FLUTTER_WEB_PORT)"
  echo "✗ $demo did not answer at http://localhost:$web/app/ within $WAIT s; see $(services_attach_hint "$root/$demo")" >&2
  failed=1
done

# The index page (Index/), with a card per demo and which ones are up.
index="$(port Index FLUTTER_WEB_PORT 2>/dev/null)"
if [[ -n "$index" ]] && answers "http://localhost:$index/"; then
  echo "🏠 Every demo, on one page: http://localhost:$index/"
fi
exit $failed

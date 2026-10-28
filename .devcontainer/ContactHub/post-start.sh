#!/usr/bin/env bash
# Runs each time the container starts (postStartCommand), after
# on-create.sh, update-content.sh and post-create.sh on the first start: starts Contact Hub's services and,
# in a codespace, makes the web app's port public, so the app opens from
# the Ports panel (or the browser tab Codespaces opens) with nothing to run.
#
# `devbox services up -b` runs process-compose in the background: the web
# app on 8890 and the API on 8891, as in ContactHub/process-compose.yaml.
# Its first start compiles the app, which takes a minute or two. Watch it
# with `devbox services attach`, stop it with `devbox services stop`.
#
# Everything is logged to ContactHub/startup.log (see startup-log.sh),
# including a watcher that records when the web app and the API answer,
# or, if they don't within 15 minutes, the services' state.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app="$(cd "$here/../.." && pwd)/ContactHub"
# shellcheck source=startup-log.sh
source "$here/startup-log.sh"
# shellcheck source=../../demos-toolchain.sh
source "$here/../../demos-toolchain.sh"
export -f services_up services_running services_socket toolchain_missing

# --watch: the detached watcher started below.
if [[ "${1:-}" == --watch ]]; then
  cd "$app" || exit 1
  web="http://localhost:${FLUTTER_WEB_PORT:-8890}/app/"
  api="http://localhost:${API_PORT:-8891}/api/health"
  started=$SECONDS
  last=""
  while ((SECONDS - started < 900)); do
    state="web $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$web")"
    state+=", api $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$api")"
    pgrep -f process-compose >/dev/null && state+=", process-compose running" ||
      state+=", process-compose NOT running"
    [[ "$state" != "$last" ]] && slog "[watch] $state"
    last=$state
    if [[ "$state" == "web 200, api 200,"* ]]; then
      slog "[watch] ready after $((SECONDS - started)) s: open port 8890 at /app/"
      exit 0
    fi
    sleep 5
  done
  slog "[watch] not ready after 15 minutes; the services' state:"
  services_running "$app"; slog "[watch]   services_running: $? (0 up, 1 down, 2 unknown)"
  for f in .devbox/compose.log process-compose.log /tmp/process-compose-"$(id -un)".log; do
    [[ -f "$f" ]] || continue
    slog "[watch] last lines of $f:"
    tail -n 60 "$f" | while IFS= read -r line; do slog "[watch]   $line"; done
  done
  exit 1
fi

startup_capture post-start
echo "===== post-start: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"
startup_facts

cd "$app" || { echo "post-start: cannot find $app" >&2; exit 1; }

# What the toolchain (devbox, or the image's own tools) still lacks:
# with devbox, this demo's `devbox install` from on-create.sh.
missing="$(toolchain_missing "$app" | tr '\n' ';')"
if [[ -n "$missing" ]]; then
  echo "post-start: the $DEMOS_TOOLCHAIN toolchain isn't ready: missing ${missing%;}"
  echo "post-start: (did on-create.sh fail? see its lines above); start the app with:"
  echo "post-start:   ./start-all.sh ContactHub"
else
  # Detached, so they outlive postStartCommand. The services' own output
  # goes to the log too.
  setsid nohup bash -c 'services_up "$1" 2>&1 |
    while IFS= read -r line; do
      printf "%s [services] %s\n" "$(date -u "+%Y-%m-%d %H:%M:%S")" "$line"
    done >>"$0"' "$startup_log" "$app" </dev/null >/dev/null 2>&1 &
  setsid nohup bash "$here/post-start.sh" --watch </dev/null >/dev/null 2>&1 &
  echo "post-start: starting the services in the background; progress in"
  echo "post-start: ContactHub/startup.log"
fi

bash "$here/public-port.sh"

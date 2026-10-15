#!/usr/bin/env bash
# Runs each time the container starts (postStartCommand), after
# post-create.sh on the first start: starts Mortgage Hub's services and,
# in a codespace, makes the web app's port public, so the app opens from
# the Ports panel (or the browser tab Codespaces opens) with nothing to run.
#
# `devbox services up -b` runs process-compose in the background: the web
# app on 8880 and the API on 8881, as in MortgageHub/process-compose.yaml.
# Its first start compiles the app, which takes a minute or two. Watch it
# with `devbox services attach`, stop it with `devbox services stop`.
set -uo pipefail

app="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/MortgageHub"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log=/tmp/mortgagehub-services.log

cd "$app" || { echo "post-start: cannot find $app" >&2; exit 1; }

if ! command -v devbox >/dev/null || [[ ! -d .devbox ]]; then
  echo "post-start: devbox is not installed here yet (did post-create.sh" >&2
  echo "post-start: fail?); start the app with: devbox services up" >&2
else
  # Detached, so it outlives postStartCommand.
  setsid nohup devbox services up -b >"$log" 2>&1 </dev/null &
  echo "post-start: starting the services in the background (log: $log)"
fi

bash "$here/public-port.sh"

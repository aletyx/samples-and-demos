#!/usr/bin/env bash
# Runs after on-create.sh when the container is created, and again whenever
# Codespaces refreshes a prebuild (updateContentCommand): builds what
# Contact Hub serves, in ContactHub/, with its scripts/build.sh (the app's release
# web build, and the API and web server compiled to native executables),
# only what is missing or older than its sources. A prebuild's snapshot
# keeps the builds, so a codespace created from one starts the app in
# seconds; without a prebuild this is the slow part of creating a
# codespace, a minute or two on a 4-core machine, during which the editor
# is already usable (devcontainer.json's waitFor). It needs no secrets.
set -euo pipefail

# Everything below also goes to ContactHub/startup.log (see startup-log.sh).
# shellcheck source=startup-log.sh
source "$(dirname "${BASH_SOURCE[0]}")/startup-log.sh"
startup_capture update-content
echo "===== update-content: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  export NIX_CONFIG="access-tokens = github.com=${GITHUB_TOKEN}"
fi
export PATH="$HOME/.nix-profile/bin:$PATH"

app="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/ContactHub"
cd "$app" || { echo "update-content: cannot find $app" >&2; exit 1; }

if [[ ! -f scripts/build.sh ]]; then
  echo "update-content: ContactHub/scripts/build.sh is missing; the app builds when it starts"
  exit 0
fi
started=$SECONDS
if devbox run -- bash scripts/build.sh; then
  echo "update-content: built in $((SECONDS - started)) s"
else
  # Not fatal: the app builds again when it starts.
  echo "update-content: scripts/build.sh failed after $((SECONDS - started)) s;" >&2
  echo "update-content: the app builds again when it starts (see above)" >&2
fi
df -h / 2>/dev/null | tail -1 | awk '{print "update-content: disk /: " $4 " free of " $2}'

#!/usr/bin/env bash
# Stops the demos ./start-all.sh starts: `devbox services stop` in each
# folder with a devbox.json and a process-compose.yaml, or only in the
# ones named. A demo that isn't running is skipped. Demos started with
# Docker Compose are not touched (docker compose -f <demo>/compose.yaml
# down).
#
#   ./stop-all.sh               # every demo
#   ./stop-all.sh ContactHub    # only these
set -uo pipefail

root="$(cd "$(dirname "$0")" && pwd)"

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

failed=0
for demo in $(demos "$@"); do
  dir="$root/$demo"
  if [[ ! -f "$dir/devbox.json" ]]; then
    echo "✗ $demo: no devbox.json in $dir" >&2
    failed=1
    continue
  fi
  # `devbox services ls` lists running processes with a PID and a status
  # (on stderr). Read whole: grep -q would close the pipe on devbox.
  status="$(cd "$dir" && devbox services ls 2>&1)"
  if ! grep -q 'Running\|Pending\|Restarting' <<<"$status"; then
    echo "· $demo is not running"
    continue
  fi
  echo "■ $demo: stopping (devbox services stop, in $dir)"
  if (cd "$dir" && devbox services stop >/dev/null 2>&1); then
    echo "✅ $demo stopped"
  else
    echo "✗ $demo: devbox services stop failed" >&2
    failed=1
  fi
done
exit $failed

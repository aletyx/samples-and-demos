#!/usr/bin/env bash
# Stops the demos ./start-all.sh starts: `devbox services stop` (or, in a
# codespace, `process-compose down`: see demos-toolchain.sh) in each
# folder with a devbox.json and a process-compose.yaml, or only in the
# ones named. A demo that isn't running is skipped. Demos started with
# Docker Compose are not touched (docker compose -f <demo>/compose.yaml
# down).
#
#   ./stop-all.sh               # every demo
#   ./stop-all.sh ContactHub    # only these
set -uo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=demos-toolchain.sh
source "$root/demos-toolchain.sh"

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
  services_running "$dir"
  case $? in
    0) ;;
    1) echo "· $demo is not running"; continue ;;
    *) echo "✗ $demo: could not read service status" >&2; failed=1; continue ;;
  esac
  echo "■ $demo: stopping ($DEMOS_TOOLCHAIN services, in $dir)"
  if services_down "$dir"; then
    echo "✅ $demo stopped"
  else
    echo "✗ $demo: stopping its services failed" >&2
    failed=1
  fi
done
exit $failed

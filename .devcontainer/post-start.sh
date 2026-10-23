#!/usr/bin/env bash
# Runs each time the container starts (postStartCommand), after
# post-create.sh on the first start: runs ./start-all.sh, which starts
# every demo and the index page, and, in a codespace, makes their ports
# public, so each app opens from the Ports panel (or from the index page's
# browser tab, which Codespaces opens) with nothing to run.
#
# start-all.sh runs `devbox services up -b` in each demo's folder: the web
# app and the API of Mortgage Hub (8880), Contact Hub (8890), PokerFace
# (8910), RoboRules (8920) and Cellfie (8930), plus the
# index on 8800.
# The first start compiles the six apps, which takes a few minutes. Watch
# one with `devbox services attach -c <demo>`; stop them with
# ./stop-all.sh.
#
# Everything is logged to startup.log at the root (see startup-log.sh),
# including start-all.sh's own lines saying when each demo answers, or,
# if one doesn't within 15 minutes, that it didn't.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=startup-log.sh
source "$here/startup-log.sh"

startup_capture post-start
echo "===== post-start: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"
startup_facts

cd "$startup_root" || { echo "post-start: cannot find $startup_root" >&2; exit 1; }

missing=()
for demo in $(startup_demos); do
  [[ -d "$demo/.devbox" ]] || missing+=("$demo")
done
if ! command -v devbox >/dev/null || [[ ${#missing[@]} -gt 0 ]]; then
  echo "post-start: devbox is not installed in ${missing[*]:-any demo} yet (did"
  echo "post-start: post-create.sh fail? see its lines above); start the"
  echo "post-start: demos with: ./start-all.sh"
else
  # Detached, so it outlives postStartCommand. start-all.sh's output, and
  # what it says when each demo answers, goes to the log too.
  setsid nohup bash -c 'WAIT=900 ./start-all.sh 2>&1 |
    while IFS= read -r line; do
      printf "%s [start-all] %s\n" "$(date -u "+%Y-%m-%d %H:%M:%S")" "$line"
    done >>"$0"' "$startup_log" </dev/null >/dev/null 2>&1 &
  echo "post-start: starting every demo in the background (./start-all.sh);"
  echo "post-start: progress in startup.log"
fi

bash "$here/public-port.sh"

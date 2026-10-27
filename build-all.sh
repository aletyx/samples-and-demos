#!/usr/bin/env bash
# Builds what every demo serves, so that ./start-all.sh only has to start
# servers: in each folder with a devbox.json and a scripts/build.sh (Mortgage
# Hub, Contact Hub, ...), `bash scripts/build.sh` under devbox, which builds
# the app's release web build and compiles the API and the web server to
# native executables, and only what is missing or older than its sources.
# One demo after another: a Flutter web build uses every core, and five at
# once thrash a small machine. A demo whose builds are up to date takes a
# second or two. A folder without a scripts/build.sh is skipped.
#
#   ./build-all.sh              # every demo
#   ./build-all.sh ContactHub   # only these
#
# The dev container runs it from updateContentCommand, so a Codespaces
# prebuild holds the builds and a codespace created from one starts every
# demo in seconds; without a prebuild it runs when the codespace is created,
# a minute or two per demo on a 4-core machine. Run it by hand before
# ./start-all.sh to see each build's output and time.
set -uo pipefail

root="$(cd "$(dirname "$0")" && pwd)"

# demos [names...]: the folders to build: the ones named, else every folder
# with a devbox.json and a process-compose.yaml.
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
built=()
for demo in $(demos "$@"); do
  dir="$root/$demo"
  if [[ ! -f "$dir/devbox.json" ]]; then
    echo "✗ $demo: no devbox.json in $dir" >&2
    failed=1
    continue
  fi
  if [[ ! -f "$dir/scripts/build.sh" ]]; then
    echo "· $demo has no scripts/build.sh: nothing to build ahead"
    continue
  fi
  echo "▶ $demo: bash scripts/build.sh (under devbox, in $dir)"
  started=$SECONDS
  if (cd "$dir" && devbox run -- bash scripts/build.sh); then
    echo "✅ $demo built in $((SECONDS - started)) s"
    built+=("$demo")
  else
    echo "✗ $demo: scripts/build.sh failed after $((SECONDS - started)) s" >&2
    failed=1
  fi
done

if [[ ${#built[@]} -gt 0 ]]; then
  echo "Built: ${built[*]}. Start them with ./start-all.sh"
fi
exit $failed

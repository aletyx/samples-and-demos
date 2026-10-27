#!/usr/bin/env bash
# Puts the release web builds the dev container image carries (/opt/demos,
# see Containerfile and build-image.sh) into the workspace, for every demo
# whose folder still has the git tree hash the build was made from; a demo
# that changed since is left to build itself (its scripts/build.sh, run by
# ./build-all.sh and before the services start). Run by on-create.sh in a
# codespace; harmless elsewhere (no /opt/demos: nothing to restore).
#
#   bash image/restore-builds.sh            # every demo
#   bash image/restore-builds.sh Cellfie    # only these
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
store=/opt/demos
manifest="$store/manifest"
if [[ ! -f "$manifest" ]]; then
  echo "restore-builds: no $manifest: nothing to restore"
  exit 0
fi
cd "$root"

wanted=("$@")
restored=()
while read -r demo hash; do
  [[ -n "$demo" ]] || continue
  if [[ ${#wanted[@]} -gt 0 ]]; then
    keep=0
    for w in "${wanted[@]}"; do [[ "$w" == "$demo" ]] && keep=1; done
    [[ $keep -eq 1 ]] || continue
  fi
  app="$(ls -d "$demo"/*_app 2>/dev/null | head -1)"
  if [[ -z "$app" || ! -d "$store/$demo/web" ]]; then
    echo "· $demo: no build in the image"
    continue
  fi
  now="$(git rev-parse "HEAD:$demo" 2>/dev/null || echo none)"
  if [[ "$now" != "$hash" ]]; then
    echo "· $demo changed since the image was made (${hash:0:7} → ${now:0:7}): it builds itself"
    continue
  fi
  rm -rf "$app/build/web"
  mkdir -p "$app/build"
  cp -a "$store/$demo/web" "$app/build/web"
  # Newer than the checkout, so scripts/build.sh sees the build as current
  # (it compares the build with the sources' times), and the record of the
  # settings it was made with newest of all (see scripts/build.sh).
  find "$app/build/web" -exec touch {} +
  touch "$app/build/web/.aityx-services"
  echo "✅ $demo: build restored from the image (${hash:0:7})"
  restored+=("$demo")
done <"$manifest"
echo "restore-builds: ${#restored[@]} restored${restored[*]:+: ${restored[*]}}"

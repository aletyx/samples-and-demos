#!/usr/bin/env bash
# Builds what `devbox services up` serves, and only what changed since the
# last build:
#   web         the app's release web build, cellfie_app/build/web/, through
#               scripts/make.sh web: under /app/, calling /api/ on its own
#               origin
#   web_server  the web server that serves it (cellfie_api/bin/
#               web_server.dart), compiled to cellfie_api/build/web_server
#   api         the API (cellfie_api/bin/server.dart), compiled to
#               cellfie_api/build/server
#   all         the three (the default)
# Run by scripts/flutter-web.sh and scripts/api.sh before they serve, or by
# hand: `devbox run build`.
#
# A target is rebuilt when its output is missing or older than any of its
# sources, so a start after no change builds nothing. A web build is
# CPU-heavy, so the demos take turns: one Flutter web build at a time
# across the whole repository, through a lock in the system's temp folder
# (the API's compiles take seconds and share a lock of their own).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/cellfie_app"
api="$root/cellfie_api"

# stale <target> <source>...: whether the target is missing or older than a
# source (a file, or any file under a folder). Missing sources are skipped.
stale() {
  local target="$1" source
  shift
  [[ -e "$target" ]] || return 0
  for source in "$@"; do
    [[ -e "$source" ]] || continue
    [[ -n "$(find "$source" -newer "$target" -print 2>/dev/null | head -1)" ]] && return 0
  done
  return 1
}

# with_lock <name> <command...>: runs the command holding the lock named
# <name>, shared by every demo of the repository; waits for whoever holds
# it, unless that process is gone (a build killed half-way).
with_lock() {
  local lock="${TMPDIR:-/tmp}/aityx-demos-$1.lock" holder
  shift
  while ! mkdir "$lock" 2>/dev/null; do
    holder="$(cat "$lock/pid" 2>/dev/null || true)"
    if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$lock"
      continue
    fi
    sleep 3
  done
  echo $$ >"$lock/pid"
  # Released however the command ends.
  _lock="$lock"
  trap 'rm -rf "$_lock"' EXIT
  "$@"
  rm -rf "$lock"
  trap - EXIT
}

build_web() {
  local out="$app/build/web"
  if ! grep -q '<base href="/app/">' "$out/index.html" 2>/dev/null ||
    stale "$out/main.dart.js" "$app/lib" "$app/web" "$app/assets" \
      "$app/pubspec.yaml" "$app/pubspec.lock" \
      "$root/version.X.txt" "$root/version.Y.txt"; then
    echo "build: web (cellfie_app/build/web is missing or older than the app)"
    with_lock flutter-web-build \
      env WEB_BASE_HREF=/app/ API_BASE_URL= bash "$root/scripts/make.sh" web
  else
    echo "build: web is up to date"
  fi
}

# compile <name>: cellfie_api/bin/<name>.dart to build/<name>, if stale.
compile() {
  local name="$1"
  if stale "$api/build/$name" "$api/bin/$name.dart" "$api/lib" \
    "$api/pubspec.yaml" "$api/pubspec.lock"; then
    echo "build: $name (dart compile exe, to cellfie_api/build/$name)"
    with_lock cellfie-api-compile bash -c '
      cd "$1" && dart pub get >/dev/null && mkdir -p build &&
        dart compile exe "bin/$2.dart" -o "build/$2" >/dev/null' _ "$api" "$name"
  else
    echo "build: $name is up to date"
  fi
}

[[ $# -gt 0 ]] || set -- all
for target in "$@"; do
  case "$target" in
    web) build_web ;;
    web_server) compile web_server ;;
    api) compile server ;;
    all)
      build_web
      compile web_server
      compile server
      ;;
    *)
      echo "error: unknown target '$target' (web, web_server, api, all)" >&2
      exit 2
      ;;
  esac
done

#!/usr/bin/env bash
# Builds the demos' dev container image (Containerfile) with every demo's
# release web build inside, and pushes it to Docker Hub (public, so anyone
# can create a codespace from it; the organization's GHCR packages can't
# be made public), tagged with the commit and as latest. Run from a laptop
# with Docker and devbox, on a clean checkout of the commit the image is
# for (usually main):
#
#   docker login -u aletyxcode             # once; a Read & Write access token
#   bash image/build-image.sh              # ./build-all.sh, then build and push
#   PUSH=0 bash image/build-image.sh       # build only, loaded locally
#
# The web builds are platform-independent, so they are made here natively
# with ./build-all.sh (devbox) and copied into the image, which is built
# for linux/amd64, the Codespaces machines, through Docker's emulation
# (its Flutter steps take a few minutes). The APIs' binaries are not in
# the image: a codespace compiles them in seconds.
#
# The staging folder image/context/ (git-ignored) holds what the
# Containerfile copies: the pubspecs, the builds and the manifest, which
# records each demo's build key (build-key.sh: the git ids of what the web
# build is made from); restore-builds.sh reuses a build only for a demo
# whose key is unchanged, so those paths must be committed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
image="${IMAGE:-docker.io/aletyxcode/samples-and-demos-devcontainer}"
cd "$root"
# shellcheck source=build-key.sh
source "$root/image/build-key.sh"

sha="$(git rev-parse --short HEAD)"
demos=()
for config in */devbox.json; do
  dir="$(dirname "$config")"
  [[ -f "$dir/scripts/build.sh" ]] && demos+=("$dir")
done

for demo in "${demos[@]}"; do
  dirty="$(build_key_paths "$demo" | xargs git status --porcelain --)"
  if [[ -n "$dirty" ]]; then
    echo "error: uncommitted changes in what $demo's web build is made from:" >&2
    echo "$dirty" >&2
    echo "error: the image records their committed git ids, so commit or stash first" >&2
    exit 1
  fi
done

echo "==> building every demo (./build-all.sh)"
./build-all.sh

context="$root/image/context"
rm -rf "$context"
mkdir -p "$context/builds" "$context/pubspecs"
: >"$context/builds/manifest"
for demo in "${demos[@]}"; do
  app="$(ls -d "$demo"/*_app)"
  api="$(ls -d "$demo"/*_api)"
  [[ -f "$app/build/web/.aityx-services" ]] || { echo "error: $app/build/web isn't a services build" >&2; exit 1; }
  mkdir -p "$context/builds/$demo" "$context/pubspecs/$demo"
  cp -a "$app/build/web" "$context/builds/$demo/web"
  printf '%s %s\n' "$demo" "$(build_key "$demo")" >>"$context/builds/manifest"
  for pkg in "$app" "$api"; do
    mkdir -p "$context/pubspecs/$demo/$(basename "$pkg")"
    cp "$pkg/pubspec.yaml" "$pkg/pubspec.lock" "$context/pubspecs/$demo/$(basename "$pkg")/"
  done
done
echo "==> manifest:"
cat "$context/builds/manifest"

push=(--push)
[[ "${PUSH:-1}" == 0 ]] && push=(--load)
echo "==> docker buildx build $image:$sha ($image:latest)"
docker buildx build --platform linux/amd64 -f "$root/image/Containerfile" \
  -t "$image:$sha" -t "$image:latest" "${push[@]}" "$context"
echo "==> done: $image:$sha and $image:latest"

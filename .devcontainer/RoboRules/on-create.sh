#!/usr/bin/env bash
# Runs once, right after the container is created (onCreateCommand), and
# in a Codespaces prebuild, whose snapshot keeps its results: makes the
# toolchain and the build ready, so that update-content.sh builds only if
# the app changed and post-start.sh only has to start it. From the
# published image (DEMOS_TOOLCHAIN=image), that is copying the image's
# release web build into the workspace; on a laptop's dev container with
# devbox, installing the toolchain. It runs before the codespace is
# assigned to a user, so it has no Codespaces secrets: post-create.sh
# reports those.
#
# This repository holds several samples. This container is for the RoboRules
# demo app, so everything below runs in RoboRules/, where devbox.json
# and devbox.lock live.
#
# Devbox has Nix resolve flakes through api.github.com: its own on
# `devbox install`, and nixpkgs when `devbox services up` first installs
# process-compose. Unauthenticated, that API allows 60 requests an hour per
# IP, and Codespaces share IPs, so it often answers 403. Codespaces provide
# a GITHUB_TOKEN; every shell hands it to Nix through NIX_CONFIG. The line
# added below reads the token from the environment, so it's never written
# to disk. Elsewhere, export GITHUB_TOKEN (e.g. `gh auth token`) if you hit
# the limit.
set -euo pipefail

# Everything below also goes to RoboRules/startup.log (see startup-log.sh).
# shellcheck source=startup-log.sh
source "$(dirname "${BASH_SOURCE[0]}")/startup-log.sh"
startup_capture on-create
echo "===== on-create: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"

line='[ -n "${GITHUB_TOKEN:-}" ] && export NIX_CONFIG="access-tokens = github.com=${GITHUB_TOKEN}"'
# ~/.profile for login shells; the top of ~/.bashrc, before its guard for
# non-interactive shells, for VS Code's terminals.
for rc in "$HOME/.profile" "$HOME/.bashrc"; do
  touch "$rc"
  if ! grep -qxF "$line" "$rc"; then
    printf '%s\n%s\n' "$line" "$(cat "$rc")" > "$rc"
  fi
done

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  export NIX_CONFIG="access-tokens = github.com=${GITHUB_TOKEN}"
fi
export PATH="$HOME/.nix-profile/bin:$PATH"

# The app, two levels up from .devcontainer/RoboRules/ and then into
# RoboRules/. Resolved from this script rather than the caller's
# directory, so it does not matter where it is run from.
app="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/RoboRules"
cd "$app" || { echo "on-create: cannot find $app" >&2; exit 1; }

# A failure says which step failed and how much disk is left, the likeliest
# cause on a small machine.
fail() {
  echo "on-create: $1 failed" >&2
  df -h / /nix 2>/dev/null >&2 || true
  exit 1
}

startup_facts
# shellcheck source=../../demos-toolchain.sh
source "$app/../demos-toolchain.sh"
if [[ "$DEMOS_TOOLCHAIN" == image ]]; then
  # The image carries Flutter, process-compose and the demos' release web
  # builds: put RoboRules's into the workspace, unless it changed since the
  # image was made (see image/restore-builds.sh).
  started=$SECONDS
  (cd "$app/.." && bash image/restore-builds.sh RoboRules) || fail "image/restore-builds.sh"
  echo "on-create: build restored in $((SECONDS - started)) s"
else
  # devbox.lock records each package's store path, so `devbox install`
  # copies them from cache.nixos.org itself; only nixpkgs comes from GitHub.
  echo "on-create: devbox install..."
  started=$SECONDS
  devbox install || fail "devbox install"
  echo "on-create: devbox install took $((SECONDS - started)) s"
fi

echo "on-create: done"
df -h /

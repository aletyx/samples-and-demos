#!/usr/bin/env bash
# Runs once when the dev container is created (postCreateCommand): installs
# each demo's toolchain, so that post-start.sh's ./start-all.sh only has to
# compile the apps.
#
# Every demo that runs as services (each folder with a devbox.json and a
# process-compose.yaml: Mortgage Hub, Contact Hub, RoboRules,
# PokerFace, and the index page in Index/) gets `devbox install` in its
# folder. They lock the same Flutter, so the Nix store is filled once and
# the later installs are quick.
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

# Everything below also goes to startup.log at the root (see startup-log.sh).
# shellcheck source=startup-log.sh
source "$(dirname "${BASH_SOURCE[0]}")/startup-log.sh"
startup_capture post-create
echo "===== post-create: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"

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

cd "$startup_root" || { echo "post-create: cannot find $startup_root" >&2; exit 1; }

# The aityx key and optional endpoint are the user's own Codespaces secrets
# (see devcontainer.json) or can be set in each demo's .env. Report only
# whether they arrived: secret values must never be printed.
if [[ -n "${AITYX_API_KEY:-}" ]]; then
  echo "post-create: AITYX_API_KEY is set; every demo can call aityx"
else
  echo "post-create: AITYX_API_KEY is not set. The apps open without it, but"
  echo "post-create: nothing that runs on aityx works. To set it, add a"
  echo "post-create: Codespaces secret at https://github.com/settings/codespaces,"
  echo "post-create: or copy each demo's .env.example to .env and fill it in."
fi
if [[ -n "${AITYX_URL:-}" ]]; then
  echo "post-create: AITYX_URL is set; every demo will use that endpoint"
else
  echo "post-create: AITYX_URL is not set; demos use https://api.aityx.ai"
fi

# A failure says which step failed and how much disk is left, the likeliest
# cause on a small machine.
fail() {
  echo "post-create: $1 failed" >&2
  df -h / /nix 2>/dev/null >&2 || true
  exit 1
}

# Each devbox.lock records its packages' store paths, so `devbox install`
# copies them from cache.nixos.org itself; only nixpkgs comes from GitHub.
startup_facts
for demo in $(startup_demos); do
  echo "post-create: devbox install in $demo/..."
  started=$SECONDS
  (cd "$demo" && devbox install) || fail "devbox install in $demo"
  echo "post-create: devbox install in $demo took $((SECONDS - started)) s"
done

echo "post-create: done"
df -h /

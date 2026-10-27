#!/usr/bin/env bash
# Runs once when the container is first assigned to a user
# (postCreateCommand), after on-create.sh (the toolchain) and
# update-content.sh (the build), which a Codespaces prebuild runs ahead of
# time; this one never runs in a prebuild, so it is where the user's own
# Codespaces secrets can be seen. It only reports whether they arrived:
# secret values must never be printed.
set -euo pipefail

# Everything below also goes to RoboRules/startup.log (see startup-log.sh).
# shellcheck source=startup-log.sh
source "$(dirname "${BASH_SOURCE[0]}")/startup-log.sh"
startup_capture post-create
echo "===== post-create: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"

app="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/RoboRules"
cd "$app" || { echo "post-create: cannot find $app" >&2; exit 1; }

# The aityx key is the user's own, passed in as a Codespaces secret (see
# devcontainer.json) or put in .env. Report only whether it arrived: the
# value must never be printed.
if [[ -n "${AITYX_API_KEY:-}" ]]; then
  echo "post-create: AITYX_API_KEY is set"
else
  echo "post-create: AITYX_API_KEY is not set. The app opens without it, but"
  echo "post-create: battles need it. To set it, add a Codespaces secret"
  echo "post-create: at https://github.com/settings/codespaces, or copy"
  echo "post-create: RoboRules/.env.example to .env and fill it in."
fi

# Whether this codespace came from a prebuild, with the toolchain and the
# build already in place (see on-create.sh and update-content.sh).
if [[ -n "${CODESPACE_NAME:-}" ]]; then
  action="$(jq -r '.ACTION_NAME // empty' /workspaces/.codespaces/shared/environment-variables.json 2>/dev/null || true)"
  case "$action" in
    createFromPrebuild) echo "post-create: created from a prebuild" ;;
    "") ;;
    *) echo "post-create: created without a prebuild ($action)" ;;
  esac
fi

startup_facts
echo "post-create: done"

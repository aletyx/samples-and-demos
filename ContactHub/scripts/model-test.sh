#!/usr/bin/env bash
# Runs the routing model's rules (contacthub_api/models/routing.json) on
# aityx.ai with fixed facts and checks the outcomes at the policy's limits
# (contacthub_api/test/model_scenarios_test.dart). Run it after changing
# the model. The aityx settings come from the environment, else the repo's
# .env; the key is only exported to the test.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
for name in AITYX_API_KEY AITYX_URL; do
  if [[ -z "${!name:-}" && -f "$root/.env" ]]; then
    value="$(sed -n "s/^${name}=//p" "$root/.env" | tail -1)"
    [[ -n "$value" ]] && export "$name=$value"
  fi
done
unset value
[[ -n "${AITYX_API_KEY:-}" ]] || { echo "error: AITYX_API_KEY isn't set (see .env.example)" >&2; exit 1; }

cd "$root/contacthub_api"
dart pub get >/dev/null
exec dart test --run-skipped --tags aityx "$@"

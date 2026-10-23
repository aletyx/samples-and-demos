# Development environment

RoboRules' environment is Contact Hub's (see its
[spec](../../ContactHub/specs/dev-environment.md)), with its own names and
ports:

- **Ports**: the web app on **8920**, the API on **8921**, so it runs
  alongside Mortgage Hub (8880/8881), Contact Hub (8890/8891) and the
  other samples in this folder (8900/8901, 8910/8911).
- `devbox services up` starts the Flutter dev server, the API and the
  health monitor ([process-compose.yaml](../process-compose.yaml)); the
  API reads `AITYX_API_KEY` and `AITYX_URL` from the environment, else
  `.env`.
- `bash scripts/model-test.sh` runs
  [test/model_scenarios_test.dart](../roborules_api/test/model_scenarios_test.dart)
  on aityx (tagged `aityx`, skipped by a plain `dart test`).
- `python3 tool/build_world.py models/world.json`, from `roborules_api/`,
  rewrites the world model.
- **Docker Compose** ([compose.yaml](../compose.yaml)): the web app's
  release build under nginx and the API compiled, with `models/` beside it.
- **Dev container** ([.devcontainer/RoboRules/](../../.devcontainer/RoboRules)),
  named **RoboRules**, forwarding 8920 and asking for the same
  `AITYX_API_KEY` Codespaces secret as the other samples.
- The app is web only.

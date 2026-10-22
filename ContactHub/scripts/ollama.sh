#!/usr/bin/env bash
# Runs the local model that reads requests: Ollama on OLLAMA_URL (default
# http://127.0.0.1:11434), unless one already answers there (the Ollama
# app, say), and pulls OLLAMA_MODEL (default qwen3:1.7b; about 1.4 GB,
# once, kept in ~/.ollama). Runs via `devbox services up` (see
# process-compose.yaml) or `devbox run local-model`. With `ready` as its
# argument, it only says whether the model is ready: exit 0 when Ollama
# lists it (the readiness probe). The settings come from the environment,
# else the repo's .env (see .env.example).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
for name in OLLAMA_URL OLLAMA_MODEL; do
  if [[ -z "${!name:-}" && -f "$root/.env" ]]; then
    value="$(sed -n "s/^${name}=//p" "$root/.env" | tail -1)"
    [[ -n "$value" ]] && export "$name=$value"
  fi
done
unset value
url="${OLLAMA_URL:-http://127.0.0.1:11434}"
model="${OLLAMA_MODEL:-qwen3:1.7b}"
# A name without a tag is ":latest", as Ollama lists it.
[[ "$model" == *:* ]] || model="$model:latest"
# The ollama command, and `ollama serve`, read where to answer from here.
export OLLAMA_HOST="$url"

# ready: exit 0 when Ollama answers at $url and lists the model.
ready() {
  curl -fs --max-time 3 "$url/api/tags" | grep -q "\"name\":\"$model\""
}

if [[ "${1:-}" == "ready" ]]; then
  ready
  exit
fi

pid=
if curl -fs --max-time 2 "$url/api/version" >/dev/null; then
  echo "Ollama already answers at $url: using it."
else
  echo "Starting Ollama at $url."
  ollama serve &
  pid=$!
  trap 'kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; exit' INT TERM
  until curl -fs --max-time 2 "$url/api/version" >/dev/null; do
    kill -0 "$pid" 2>/dev/null || { echo "error: Ollama stopped" >&2; exit 1; }
    sleep 1
  done
fi

if ready; then
  echo "The local model $model is ready at $url."
else
  echo "Pulling the local model $model (once; about 1.4 GB for qwen3:1.7b)."
  ollama pull "$model"
  echo "The local model $model is ready at $url."
fi

if [[ -n "$pid" ]]; then
  wait "$pid"
else
  # Nothing to run: Ollama is someone else's. Stay up, so the service
  # stays "running" for process-compose.
  while sleep 3600; do :; done
fi

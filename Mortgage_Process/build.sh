#!/usr/bin/env bash
set -ex

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SETTINGS="${SCRIPT_DIR}/../settings.xml"

cd "${SCRIPT_DIR}"
exec mvn -B -s "${SETTINGS}" clean install "$@"

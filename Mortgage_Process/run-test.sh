#!/usr/bin/env bash
# Builds the Mortgage_Process kjar (via build.sh, Aletyx v10 stack), deploys
# it to the locally running v10 KIE server (demo-kie-server-v10 on WildFly 35,
# port 8180), starts the MortgageApprovalProcess, then lists process instances
# and verifies one is active.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

KIE_SERVER="${KIE_SERVER:-http://localhost:8180/kie-server/services/rest/server}"
KIE_USER="${KIE_USER:-admin}"
KIE_PASS="${KIE_PASS:-admin123!}"

GROUP_ID="mortgage-process"
ARTIFACT_ID="mortgage-process"
VERSION="1.0.0-SNAPSHOT"
CONTAINER_ID="${ARTIFACT_ID}_${VERSION}"
PROCESS_ID="Mortgage_Process.MortgageApprovalProcess"

CURL=(curl -sS -u "${KIE_USER}:${KIE_PASS}" \
      -H 'Accept: application/json' -H 'Content-Type: application/json')

echo "==> Building ${GROUP_ID}:${ARTIFACT_ID}:${VERSION} (kjar, v10 stack)"
"${SCRIPT_DIR}/build.sh" -q -DskipTests

echo "==> Deploying container ${CONTAINER_ID} to ${KIE_SERVER}"
# Recreate the container so the freshly installed SNAPSHOT is picked up.
"${CURL[@]}" -X DELETE "${KIE_SERVER}/containers/${CONTAINER_ID}" >/dev/null || true
"${CURL[@]}" -X PUT "${KIE_SERVER}/containers/${CONTAINER_ID}" -d @- <<EOF | python3 -m json.tool
{
  "container-id": "${CONTAINER_ID}",
  "release-id": {
    "group-id": "${GROUP_ID}",
    "artifact-id": "${ARTIFACT_ID}",
    "version": "${VERSION}"
  }
}
EOF

echo "==> Waiting for container to start"
status=UNKNOWN
for i in $(seq 1 30); do
  status="$("${CURL[@]}" "${KIE_SERVER}/containers/${CONTAINER_ID}" |
    python3 -c "import json,sys; print(json.load(sys.stdin)['result']['kie-container']['status'])" 2>/dev/null || echo UNKNOWN)"
  [ "${status}" = "STARTED" ] && break
  if [ "${status}" = "FAILED" ]; then
    echo "error: container failed to start" >&2
    exit 1
  fi
  sleep 2
done
if [ "${status}" != "STARTED" ]; then
  echo "error: container did not reach STARTED (last status: ${status})" >&2
  exit 1
fi
echo "container status: ${status}"

echo "==> Starting process ${PROCESS_ID}"
# The process requires an 'application' variable; the Validation rule task
# NPEs if it is null. Top-level objects use the KIE server wrapped-type form.
instance_id="$("${CURL[@]}" -X POST \
  "${KIE_SERVER}/containers/${CONTAINER_ID}/processes/${PROCESS_ID}/instances" \
  -d @- <<'EOF'
{
  "application": {
    "com.myspace.mortgage_app.Application": {
      "applicant": {
        "name": "Frank Kafka",
        "annualincome": 60000,
        "address": "Elm St. 123",
        "ssn": 123456789,
        "creditrating": 700
      },
      "property": {
        "age": 8,
        "address": "Main St. 456",
        "locale": "Rural",
        "saleprice": 300000
      },
      "downpayment": 60000,
      "amortization": 25,
      "mortgageamount": 240000
    }
  }
}
EOF
)"
if ! [[ "${instance_id}" =~ ^[0-9]+$ ]]; then
  echo "error: failed to start process: ${instance_id}" >&2
  exit 1
fi
echo "started process instance: ${instance_id}"

echo "==> Listing active process instances"
instances_json="$("${CURL[@]}" \
  "${KIE_SERVER}/queries/processes/instances?status=1&pageSize=100")"
echo "${instances_json}" | python3 -c '
import json, sys
data = json.load(sys.stdin)
instances = data.get("process-instance", [])
for pi in instances:
    print("  instance %s: %s (state=%s, container=%s)" % (
        pi["process-instance-id"], pi["process-id"],
        pi["process-instance-state"], pi["container-id"]))
if not instances:
    print("  (none)")
'

echo "==> Verifying instance ${instance_id} of ${PROCESS_ID} is active"
echo "${instances_json}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
instances = data.get('process-instance', [])
ok = any(pi['process-id'] == '${PROCESS_ID}'
         and pi['process-instance-id'] == ${instance_id}
         and pi['process-instance-state'] == 1
         for pi in instances)
sys.exit(0 if ok else 1)
" || { echo "FAILURE: started instance not found among active process instances" >&2; exit 1; }

echo "SUCCESS: process instance ${instance_id} (${PROCESS_ID}) is active on ${CONTAINER_ID}"

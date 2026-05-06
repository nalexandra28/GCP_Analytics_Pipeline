#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/lib.sh"

: "${WS_GATEWAY_TOKEN:?Set WS_GATEWAY_TOKEN in repo-root .env}"

SVC="${WS_GATEWAY_SERVICE_NAME:-ws-gateway}"
command -v gcloud &>/dev/null || { echo "gcloud required" >&2; exit 1; }

HTTP_URL="$(gcloud run services describe "${SVC}" \
  --region="${GCP_REGION}" \
  --project="${GCP_PROJECT_ID}" \
  --format='value(status.url)')"

if [[ -z "${HTTP_URL}" ]]; then
  echo "No Cloud Run URL for '${SVC}' in ${GCP_REGION}. Deploy: infra/scripts/32-cloud-run-ws-gateway.sh" >&2
  exit 1
fi

if [[ "${HTTP_URL}" == https://* ]]; then
  CLIENT_WS_URL="wss://${HTTP_URL#https://}/ws"
elif [[ "${HTTP_URL}" == http://* ]]; then
  CLIENT_WS_URL="ws://${HTTP_URL#http://}/ws"
else 
  echo "Unexpected URL from gcloud: ${HTTP_URL}" >&2
  exit 1
fi


CONFIG_PATH="${REPO_ROOT}/dashboard/config.js"

cat > "${CONFIG_PATH}" <<EOF
const WS_URL = "${CLIENT_WS_URL}";
const WS_GATEWAY_TOKEN = "${WS_GATEWAY_TOKEN}";
EOF

echo "Wrote config to ${CONFIG_PATH}"

echo "Wrote WebSocket base: ${CLIENT_WS_URL}"
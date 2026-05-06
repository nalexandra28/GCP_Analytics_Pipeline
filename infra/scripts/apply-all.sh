#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

chmod +x "${SCRIPT_DIR}"/*.sh

"${SCRIPT_DIR}/00-enable-apis.sh"
"${SCRIPT_DIR}/10-pubsub-topic.sh"
"${SCRIPT_DIR}/20-firestore-database.sh"
"${SCRIPT_DIR}/30-cloud-run-fast-lazy-bee.sh"
"${SCRIPT_DIR}/31-cloud-run-analytics-function.sh"
"${SCRIPT_DIR}/32-cloud-run-websocket.sh"

echo ""
echo "All steps finished. Topic: movie-events | Firestore: (default) (project ${GCP_PROJECT_ID}, region ${GCP_REGION})"

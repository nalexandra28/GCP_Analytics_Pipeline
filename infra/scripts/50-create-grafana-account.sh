#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/lib.sh"

if ! gcloud iam service-accounts describe "grafana-monitoring@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${GCP_PROJECT_ID}" &>/dev/null; then
  echo "Creating grafana-monitoring service account..."
  gcloud iam service-accounts create grafana-monitoring \
    --display-name="Grafana Monitoring" \
    --project="${GCP_PROJECT_ID}"
else
  echo "Service account already exists, skipping creation."
fi

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:grafana-monitoring@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/monitoring.viewer"

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:grafana-monitoring@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.viewer"

gcloud iam service-accounts keys create "${REPO_ROOT}/grafana-key.json" \
  --iam-account="grafana-monitoring@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
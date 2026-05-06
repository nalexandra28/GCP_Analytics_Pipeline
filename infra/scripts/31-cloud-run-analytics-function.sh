#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/lib.sh"

FUNCTION_NAME="processEvent"
REGION="${GCP_REGION}"
RUNTIME="nodejs22"
ENTRY_POINT="processEvent"
SOURCE_DIR="${REPO_ROOT}/services/analytics-function"
TOPIC="movie-events"

PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT_ID}" --format='value(projectNumber)')"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Setting IAM roles..."

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/datastore.user" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/pubsub.subscriber" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/pubsub.publisher" \
  --quiet

echo "Deploying function ${FUNCTION_NAME}..."

gcloud functions deploy "${FUNCTION_NAME}" \
  --gen2 \
  --runtime="${RUNTIME}" \
  --region="${REGION}" \
  --source="${SOURCE_DIR}" \
  --entry-point="${ENTRY_POINT}" \
  --trigger-topic="${TOPIC}" \
  --service-account="${COMPUTE_SA}" \
  --set-env-vars="GCP_PROJECT_ID=${GCP_PROJECT_ID}" \
  --project="${GCP_PROJECT_ID}"

gcloud functions add-invoker-policy-binding "${FUNCTION_NAME}" \
  --region="${REGION}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --project="${GCP_PROJECT_ID}" \
  --quiet

echo "Done."


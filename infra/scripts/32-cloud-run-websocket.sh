#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/lib.sh"

PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT_ID}" --format='value(projectNumber)')"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/pubsub.subscriber" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/logging.logWriter" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet


AR_REPOSITORY="myrepo"
AR_IMAGE="ws-gateway"
AR_TAG="v1"
CLOUD_RUN_SERVICE="ws-gateway"
APP_PORT=8080

APP_DIR="${REPO_ROOT}/services/websocket-gateway"
IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${AR_REPOSITORY}/${AR_IMAGE}:${AR_TAG}"

if ! gcloud artifacts repositories describe "${AR_REPOSITORY}" \
  --location="${GCP_REGION}" --project="${GCP_PROJECT_ID}" &>/dev/null; then
  echo "Creating Artifact Registry repo ${AR_REPOSITORY} ..."
  gcloud artifacts repositories create "${AR_REPOSITORY}" \
    --repository-format=docker \
    --location="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --description="GCP Project"
fi

echo "Build + push ${IMAGE} ..."
gcloud builds submit "${APP_DIR}" --tag="${IMAGE}" --project="${GCP_PROJECT_ID}"

echo "Deploy ${CLOUD_RUN_SERVICE} ..."
NOTIF_SUB="event-notifications-ws-gateway"

gcloud run deploy "${CLOUD_RUN_SERVICE}" \
  --image="${IMAGE}" \
  --platform=managed \
  --region="${GCP_REGION}" \
  --allow-unauthenticated \
  --port="${APP_PORT}" \
  --min-instances=1 \
  --max-instances=1 \
  --set-env-vars="LOG_LEVEL=INFO,GCP_PROJECT_ID=${GCP_PROJECT_ID},EVENT_NOTIFICATIONS_SUB=${NOTIF_SUB}" \
  --project="${GCP_PROJECT_ID}"

echo "Done."
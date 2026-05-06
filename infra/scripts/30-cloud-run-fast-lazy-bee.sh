#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/lib.sh"

: "${MONGO_URL:?}"

AR_REPOSITORY="myrepo"
AR_IMAGE="fast-lazy-bee"
AR_TAG="v1"
CLOUD_RUN_SERVICE="fast-lazy-bee"
APP_PORT=3000

PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT_ID}" --format='value(projectNumber)')"
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet

COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/logging.logWriter" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/pubsub.publisher" \
  --quiet

APP_DIR="${REPO_ROOT}/fast-lazy-bee"
IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${AR_REPOSITORY}/${AR_IMAGE}:${AR_TAG}"

if ! gcloud artifacts repositories describe "${AR_REPOSITORY}" \
  --location="${GCP_REGION}" --project="${GCP_PROJECT_ID}" &>/dev/null; then
  echo "Creating Artifact Registry repo ${AR_REPOSITORY} ..."
  gcloud artifacts repositories create "${AR_REPOSITORY}" \
    --repository-format=docker \
    --location="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --description="PCD"
fi

echo "Build + push ${IMAGE} ..."
gcloud builds submit "${APP_DIR}" --tag="${IMAGE}" --project="${GCP_PROJECT_ID}"

echo "Deploy ${CLOUD_RUN_SERVICE} ..."
gcloud run deploy "${CLOUD_RUN_SERVICE}" \
  --image="${IMAGE}" \
  --platform=managed \
  --region="${GCP_REGION}" \
  --allow-unauthenticated \
  --port="${APP_PORT}" \
  --min-instances=1 \
  --max-instances=1 \
  --set-env-vars="MONGO_URL=${MONGO_URL},NODE_ENV=production,APP_PORT=${APP_PORT},GCP_PROJECT_ID=${GCP_PROJECT_ID}" \
  --project="${GCP_PROJECT_ID}"

echo "Done."

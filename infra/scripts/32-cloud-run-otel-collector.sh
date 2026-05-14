#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/lib.sh"

PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT_ID}" --format='value(projectNumber)')"

COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
OTEL_SA="otel-collector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "${OTEL_SA}" \
  --project="${GCP_PROJECT_ID}" &>/dev/null; then
  gcloud iam service-accounts create otel-collector-sa \
    --display-name="OTel Collector" \
    --project="${GCP_PROJECT_ID}"
fi


gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${OTEL_SA}" \
  --role="roles/monitoring.metricWriter" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT_ID}" \
  --member="serviceAccount:${OTEL_SA}" \
  --role="roles/logging.logWriter" \
  --quiet

APP_DIR="${REPO_ROOT}/services/otel-collector"
AR_REPOSITORY="myrepo"
AR_IMAGE="otel-collector"
AR_TAG="v1"
IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${AR_REPOSITORY}/${AR_IMAGE}:${AR_TAG}"
CLOUD_RUN_SERVICE="otel-collector"

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
gcloud run deploy otel-collector \
  --image="${IMAGE}" \
  --region="${GCP_REGION}" \
  --allow-unauthenticated \
  --port 4318 \
  --min-instances=1 \
  --max-instances=1 \
  --service-account="otel-collector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --service-account="${OTEL_SA}" \
  --project="${GCP_PROJECT_ID}"

echo "Done."
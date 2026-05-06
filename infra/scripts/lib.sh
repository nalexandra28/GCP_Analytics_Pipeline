#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Copy .env.example to .env at the repository root and set GCP_PROJECT_ID."
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID in .env at repository root}"
: "${GCP_REGION:=us-central1}"

if ! gcloud projects describe "${GCP_PROJECT_ID}" --quiet &>/dev/null; then
  echo "Creating project ${GCP_PROJECT_ID} ..."
  gcloud projects create "${GCP_PROJECT_ID}" --quiet
  BILLING_ACCOUNT="$(gcloud billing accounts list --format='value(name)' --limit=1)"
  gcloud billing projects link "${GCP_PROJECT_ID}" \
    --billing-account="${BILLING_ACCOUNT}" --quiet
else
  echo "Project ${GCP_PROJECT_ID} already exists, skipping creation."
fi

gcloud config set project "${GCP_PROJECT_ID}" --quiet

export GCP_PROJECT_ID GCP_REGION
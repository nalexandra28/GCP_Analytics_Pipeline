#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

PUBSUB_TOPIC_EVENTS="movie-events"
PUBSUB_TOPIC_NOTIFICATIONS="event-notifications"
PUBSUB_SUB_NOTIFICATIONS="event-notifications-ws-gateway"

if gcloud pubsub topics describe "${PUBSUB_TOPIC_EVENTS}" \
  --project="${GCP_PROJECT_ID}" &>/dev/null; then
  echo "Topic ${PUBSUB_TOPIC_EVENTS} already exists."
else
  echo "Creating topic ${PUBSUB_TOPIC_EVENTS} ..."
  gcloud pubsub topics create "${PUBSUB_TOPIC_EVENTS}" \
    --project="${GCP_PROJECT_ID}"
  echo "Created."
fi

if gcloud pubsub topics describe "${PUBSUB_TOPIC_NOTIFICATIONS}" \
  --project="${GCP_PROJECT_ID}" &>/dev/null; then
  echo "Topic ${PUBSUB_TOPIC_NOTIFICATIONS} already exists."
else
  echo "Creating topic ${PUBSUB_TOPIC_NOTIFICATIONS} ..."
  gcloud pubsub topics create "${PUBSUB_TOPIC_NOTIFICATIONS}" \
    --project="${GCP_PROJECT_ID}"
  echo "Created."
fi

if gcloud pubsub subscriptions describe "${PUBSUB_SUB_NOTIFICATIONS}" \
  --project="${GCP_PROJECT_ID}" &>/dev/null; then
  echo "Subscription ${PUBSUB_SUB_NOTIFICATIONS} (topic ${PUBSUB_TOPIC_NOTIFICATIONS}) already exists."
else
  echo "Creating pull subscription ${PUBSUB_SUB_NOTIFICATIONS} ..."
  gcloud pubsub subscriptions create "${PUBSUB_SUB_NOTIFICATIONS}" \
    --topic="${PUBSUB_TOPIC_NOTIFICATIONS}" \
    --project="${GCP_PROJECT_ID}"
  echo "Created."
fi

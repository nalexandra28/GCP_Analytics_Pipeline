#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${TEST_DIR}/../.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Copy .env.example to .env at the repository root and set GCP_PROJECT_ID."
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

NUM_CLIENTS="${1:-30}"
DURATION="${2:-60}"

MOVIE_IDS=(
    "573a139cf29313caabcf560f"
    "573a13a0f29313caabd041db"
    "573a1390f29313caabcd42e8"
    "573a1390f29313caabcd446f"
)

HTTP_URL="$(gcloud run services describe ws-gateway \
    --region="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --format='value(status.url)')"
WS_URL="wss://${HTTP_URL#https://}/ws"

SERVICE_URL="$(gcloud run services describe fast-lazy-bee \
    --region="${GCP_REGION}" \
    --project="${GCP_PROJECT_ID}" \
    --format='value(status.url)')"

echo "WS:      ${WS_URL}"
echo "Service: ${SERVICE_URL}"
echo "Clients: ${NUM_CLIENTS} for ${DURATION}s"

command -v websocat &>/dev/null || { echo "websocat required: install websocat" >&2; exit 1; }
command -v curl &>/dev/null || { echo "curl required" >&2; exit 1; }

PIDS=()

WS_CLIENTS=$(( NUM_CLIENTS * 70 / 100 ))
echo "spawning ${WS_CLIENTS} WebSocket clients..."
for i in $(seq 1 "${WS_CLIENTS}"); do
    websocat --no-close "${WS_URL}" > /dev/null 2>&1 &
    PIDS+=($!)
done

GET_CLIENTS=$(( NUM_CLIENTS - WS_CLIENTS ))
echo "spawning ${GET_CLIENTS} GET clients..."
for i in $(seq 1 "${GET_CLIENTS}"); do
    (
        END=$(( SECONDS + DURATION ))
        while [[ $SECONDS -lt $END ]]; do
            MOVIE_ID="${MOVIE_IDS[$RANDOM % ${#MOVIE_IDS[@]}]}"
            curl -s "${SERVICE_URL}/api/v1/movies/${MOVIE_ID}" > /dev/null
            sleep $(( RANDOM % 5 + 1 ))
        done
    ) &
    PIDS+=($!)
done

echo "all clients running for ${DURATION}s..."
sleep "${DURATION}"

echo "stopping all clients..."
for pid in "${PIDS[@]}"; do
    kill "${pid}" 2>/dev/null || true
done

echo "done."
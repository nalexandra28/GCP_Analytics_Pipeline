# Infrastructure

Shell scripts under `[scripts/](scripts/)` provision GCP resources. `lib.sh` loads the repo-root `.env` and requires `**GCP_PROJECT_ID**`; `**GCP_REGION**` defaults to `us-central1` if unset.

## Prerequisites

1. [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) with `gcloud` on `PATH`.
2. Billing enabled on the GCP project; `gcloud auth login`.

### API enablement

`00-enable-apis.sh` enables: `pubsub.googleapis.com`, `firestore.googleapis.com`, `cloudbuild.googleapis.com`, `run.googleapis.com`, `artifactregistry.googleapis.com`.

## `.env` (repo root)


| Variable                  | Required            | Notes                                                                                      |
| ------------------------- | ------------------- | ------------------------------------------------------------------------------------------ |
| `GCP_PROJECT_ID`          | yes                 |                                                                                            |
| `GCP_REGION`              | no                  | default `us-central1`                                                                      |
| `MONGO_URL`               | for `15-` and `30-` | Atlas SRV string; see below                                                                |
| `WS_GATEWAY_DEMO_TOKEN`   | for `32-` and `33-` | WebSocket `?token=`; written to `dashboard/config.js` by `33-write-dashboard-config.sh`    |
| `WS_GATEWAY_SERVICE_NAME` | optional, `33-`     | Cloud Run service for `gcloud run services describe` (default `ws-gateway`, same as `32-`) |


## Scripts


| Script                               | Role                                                            |
| ------------------------------------ | --------------------------------------------------------------- |
| `00-enable-apis.sh`                  | Enable APIs                                                     |
| `10-pubsub-topic.sh`                 | Create Pub/Sub topic `movie-events` and `event-notifications`   |
| `15-mongorestore-sample-mflix.sh`    | `curl` sample_mflix archive, `mongorestore` (needs `MONGO_URL`) |
| `20-firestore-database.sh`           | Create Firestore DB `(default)` if missing                      |
| `30-cloud-run-fast-lazy-bee.sh`      | Build + deploy `fast-lazy-bee`                                  |
| `31-cloud-run-analytics-function.sh` | Build + deploy the analytics Cloud Function                     |
| `32-cloud-run-ws-gateway.sh`         | Build + deploy Python `ws-gateway`                              |
| `33-write-dashboard-config.sh`       | Write `dashboard/config.js`                                     |
| `apply-all.sh`                       | Runs `00` through `33` (not `15`)                               |


## Execution

```bash
cd path/to/PCD_Homework2
cp .env.example .env
cd infra/scripts
chmod +x *.sh
./apply-all.sh
```


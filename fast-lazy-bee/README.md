# PCD Homework 2 — Real-time analytics pipeline (Fast Lazy Bee + GCP)

This repository contains the **PCD** coursework submission: an extension of the **Fast Lazy Bee** movie API into an event-driven analytics pipeline on **Google Cloud Platform**. The baseline REST application remains under `fast-lazy-bee/`; additional components provide **Pub/Sub** messaging, **Firestore**-backed analytics, a serverless consumer, a **WebSocket** gateway, and a static dashboard.

## Repository layout


| Path                                                           | Description                                                                                  |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `[fast-lazy-bee/](fast-lazy-bee/)`                             | Fastify/TypeScript **REST API**                                                              |
| `[services/analytics-function/](services/analytics-function/)` | **Serverless** consumer for **Pub/Sub**                                                      |
| `[services/ws-gateway/](services/ws-gateway/)`                 | **WebSocket** gateway                                                                        |
| `[dashboard/](dashboard/)`                                     | **HTML** client                                                                              |
| `[infra/scripts/](infra/scripts/)`                             | **Bash** + `gcloud`: APIs, Pub/Sub topic `**resource-events`**, **Cloud Firestore** (native) |


## Provisioning from a clean clone

1. Select or create a GCP project; authenticate (`gcloud auth login`).
2. At the repository root, copy `[.env.example](.env.example)` to `.env` and set `GCP_PROJECT_ID` and any optional variables. Run `[infra/scripts/apply-all.sh](infra/scripts/apply-all.sh)` as described in `[infra/README.md](infra/README.md)`.
3. Deploy additional components from their respective directories when implemented, following each **README**.

# Analytics function

Google Cloud Function (2nd gen) that consumes **Pub/Sub push** events about movie activity, records analytics in **Firestore**, and republishes a **downstream notification** on another topic.

## Runtime and entry point


| Item              | Value                               |
| ----------------- | ----------------------------------- |
| Runtime           | Node.js                             |
| Framework         | `@google-cloud/functions-framework` |
| CloudEvent target | `processEvent`                      |


## Trigger and environment

- **Trigger topic** (deploy): `movie-events` — the function is subscribed as a push subscriber for messages published to this topic (`--trigger-topic` in `31-cloud-run-analytics-function.sh`).
- **Environment**
  - `GCP_PROJECT_ID` — set at deploy time. Used by `utils/pub-sub-utils.js` to build the Pub/Sub client; if unset, the client uses default application credentials resolution.

## Data flow

1. Pub/Sub delivers a **CloudEvent** whose payload includes the Pub/Sub message: `data` (base64 JSON) and `messageId`.
2. The handler decodes the JSON, reads `event` and passes `messageId`, `eventName`, and the full decoded object into `processEvent`.
3. For supported events, the function reads/writes Firestore and may publish to Pub/Sub.

## Event handling


| `event` field                      | Behavior                                                                                               |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `movie_viewed`                     | See [Movie viewed](#movie_viewed) below.                                                               |
| `movies_viewed`, `comments_viewed` | No Firestore write and no publish; result status `skipped for now` (placeholders for future work).     |
| Any other                          | No side effects; result status `ignored` (includes the event name in the returned object for logging). |


Missing `message` / `data` on the event: the handler logs and returns without throwing (no retry).

## `movie_viewed`

1. **Idempotency** — looks up `processed-messages/{messageId}`. If the document exists, processing stops with status `duplicate` (no second write, no second publish).
2. **Write `movie-stats`** — adds a new document (auto ID) with:
  - `movieId`, `movieTitle`
  - `timestamp` (ISO string at processing time)
  - `expiresAt` — one hour after processing (intended for TTL or cleanup; enforcement is via Firestore/ops configuration, not in this code)
3. **Validate** — Collection entries data shapes are checked with [Typebox](https://github.com/sinclairzx81/typebox) schemas in `schemas/collection-schemas.js` (before `expiresAt` is added) and `schemas/messages-schemas.js` (outbound message).
4. **Mark processed** — `processed-messages/{messageId}` is set with `movieId` and `processedAt`.
5. **Publish** — JSON to Pub/Sub topic `event-notifications` via `utils/pub-sub-utils.js`. The outbound shape matches `PublishedMessageSchema`.

`**sourceEventId` on the outbound message:** After a new `movie-stats` document is created, the publish step includes `sourceEventId: <that document’s ID>`. The WebSocket gateway uses it only to **deduplicate** the same notification if Pub/Sub redelivers it: two different physical views get two different Firestore documents, so two different IDs, and the gateway keeps a separate “recent” line for each view. (This is not the same as the inbound `messageId` from `movie-events`, which is what `processed-messages` uses to avoid processing the same upstream message twice.)

## Firestore collections


| Collection           | Role                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------ |
| `movie-stats`        | One document **added** per successful `movie_viewed` handling, stores event details. |
| `processed-messages` | Stores per-message processing for deduplication.                                     |


## Pub/Sub


| Topic                 | Direction                  |
| --------------------- | -------------------------- |
| `movie-events`        | Inbound (function trigger) |
| `event-notifications` | Outbound                   |


Deploy script grants the runtime service account **Pub/Sub subscriber** and **Pub/Sub publisher** (and **Datastore user** for Firestore).

## Local development

```bash
cd services/analytics-function
npm install
npm start
```

`functions-framework` runs the `processEvent` target. You still need Application Default Credentials and matching Firestore/Pub/Sub access for end-to-end behavior.

---

**Deploy:** `infra/scripts/31-cloud-run-analytics-function.sh` (requires `GCP_PROJECT_ID`, `GCP_REGION`, and `gcloud` context).
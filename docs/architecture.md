# Architecture

## Data flow

```
Simulator ──MQTT──► Ingestion ──► TimescaleDB (telemetry hypertable)
  (replay of                       │ validation
   C-MAPSS/IMS/AI4I)                └─► dead_letter
                                    │
                                    ▼
                          Feature Pipeline (ml/src/factorypulse_ml)
                                    │  rolling stats, FFT bands, trends
                                    ├─► features (hypertable)
                                    └─► Redis (online feature cache)
                                    │
      MLflow ◄── Training (torch/lightgbm) ◄── DVC-tracked data
      registry        │
                       ▼
                Inference Service ──► Alerting Service ──► alerts, health_scores
                       │ anomaly + RUL + failure mode          │ webhooks
                       ▼                                       ▼
                Copilot Service ◄──── Qdrant (manuals, logs)
                       │  tools: health, RUL, manuals, history
                       ▼
                Streamlit Console (fleet, alerts, chat, MLOps)
```

## Services

Each service under `services/` is an independently deployable container
with its own `Dockerfile` and `requirements.txt`. The `ml/` package is
installed into both the training environment and the `inference`
service, so feature computation is defined once and never drifts
between training and serving.

- **simulator** — replays the public datasets as live MQTT telemetry at
  a configurable speed, optionally injecting faults for demos.
- **ingestion** — subscribes to MQTT, validates payloads (schema,
  physical range, timestamp ordering), batch-writes to TimescaleDB, and
  routes invalid payloads to `dead_letter` with a reason code.
- **inference** — FastAPI service serving anomaly score, RUL, and
  failure-mode probabilities per machine, loading models from the
  MLflow registry with shadow-mode evaluation of candidate models.
- **alerting** — converts model outputs into deduplicated,
  severity-ranked alerts using hysteresis (open above a high threshold,
  close only below a lower one), computes the composite 0-100 health
  score, and dispatches webhooks for CRITICAL alerts.
- **copilot** — LangGraph agent with 5 tools (machine health, recent
  anomalies, RUL, manual search, maintenance history) backed by hybrid
  RAG over Qdrant; drafts grounded work orders with inline citations.
- **console** — Streamlit dashboard: fleet grid, machine detail, alert
  queue, copilot chat, and an MLOps page (model versions, drift, shadow
  deltas).

## Shared ML package

`ml/src/factorypulse_ml` is installed as a package (see
`ml/pyproject.toml`) rather than copy-pasted into each service. Both the
offline training scripts and the online `inference` service import the
same feature-computation code, which is the only way to guarantee
training/serving parity — if these were two separate implementations,
they would eventually diverge and the model would see different inputs
in production than it was trained on.

## Storage

- **TimescaleDB** — telemetry (hypertable), features (hypertable),
  everything else (machines, sensors, alerts, work_orders, users,
  audit_log, drift_reports) as regular Postgres tables in the same
  instance. See `scripts/init_db.sql` for the full schema.
- **Redis** — online feature cache, read by `inference` on the hot path.
- **Qdrant** — manual/log chunk vectors for the copilot's RAG retrieval.
- **MLflow** — experiment tracking + model registry (Staging/Production
  promotion).

Full ADRs for the anomaly detection ensemble and shadow deployment
policy are in `docs/adr/`.

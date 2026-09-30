# FactoryPulse

Real-time predictive maintenance & equipment intelligence platform.
Ingests sensor telemetry, detects anomalies, predicts Remaining Useful
Life (RUL), and exposes a RAG-grounded maintenance copilot that turns
alerts into diagnosed, citation-backed work orders.

## Quick start

```bash
cp .env.example .env
make demo   # infra + seed + up — full launch
```

## Services

| Service               | Port | Role                                                          |
|------------------------|------|----------------------------------------------------------------|
| `services/simulator`  | —    | MQTT replayer + fault injector — replays datasets as live telemetry |
| `services/ingestion`  | —    | Validates, batch-writes, and dead-letters incoming telemetry  |
| `services/inference`  | 8001 | FastAPI model serving — anomaly, RUL, failure-mode + shadow deployment |
| `services/alerting`   | —    | Hysteresis alert engine + composite health scoring + webhooks |
| `services/copilot`    | 8002 | LangGraph agent, 5 tools, hybrid RAG over manuals/logs         |
| `services/console`    | 8501 | Streamlit dashboard — fleet, alerts, copilot chat, MLOps       |

## Datasets

| Dataset            | Source                          | ML task                        |
|---------------------|----------------------------------|---------------------------------|
| C-MAPSS (FD001-FD004)| NASA Prognostics Data Repository | RUL prediction                  |
| IMS Bearings        | UC Irvine / NASA                 | Anomaly detection               |
| AI4I 2020           | UCI ML Repository                | Failure-mode classification     |

Download via `python scripts/download_datasets.py`, then version with DVC
(see `docs/architecture.md`).

## Milestone roadmap

| Milestone | Scope                                                        |
|-----------|---------------------------------------------------------------|
| M1        | Architecture & project setup (this milestone)                 |
| M2        | Data engineering & feature pipeline (simulator, ingestion, features) |
| M3        | Core ML — anomaly detection, RUL, failure classification      |
| M4        | Serving & alerting — inference API, hysteresis engine, console v1 |
| M5        | GenAI copilot — RAG, LangGraph agent, work-order generation    |
| M6        | MLOps hardening & demo — drift, CI/CD, load tests, docs, video |

## Architecture & decisions

See `docs/architecture.md` for the system diagram and `docs/adr/` for
the reasoning behind key technical decisions (anomaly ensemble design,
shadow deployment policy).

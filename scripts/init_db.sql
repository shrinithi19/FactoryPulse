-- FactoryPulse database schema
-- Runs automatically via /docker-entrypoint-initdb.d/ on first container start.

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ══════════════════════════════════════════════════════════════════
-- Asset registry
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS machines (
    id            VARCHAR(50) PRIMARY KEY,
    machine_class VARCHAR(64)  NOT NULL,   -- CNC_Mill, Turbofan, Bearing_Rig, Centrifugal_Pump
    location      VARCHAR(128),
    install_date  DATE,
    status        VARCHAR(16) NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'maintenance', 'retired'))
);

CREATE TABLE IF NOT EXISTS sensors (
    id         VARCHAR(100) PRIMARY KEY,
    machine_id VARCHAR(50) NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    type       VARCHAR(32) NOT NULL,       -- temperature, vibration, pressure, rpm, current
    unit       VARCHAR(16),
    min_valid  DOUBLE PRECISION,
    max_valid  DOUBLE PRECISION,
    UNIQUE (machine_id, type)
);

-- ══════════════════════════════════════════════════════════════════
-- Telemetry (raw + rollups)
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS telemetry (
    ts         TIMESTAMPTZ      NOT NULL,
    machine_id VARCHAR(50)      NOT NULL,
    sensor_id  VARCHAR(100)     NOT NULL,
    value      DOUBLE PRECISION NOT NULL,
    quality    SMALLINT         DEFAULT 0  -- 0 = good, nonzero = flagged
);

SELECT create_hypertable('telemetry', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_telemetry_machine_ts ON telemetry (machine_id, ts DESC);

CREATE MATERIALIZED VIEW IF NOT EXISTS telemetry_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', ts) AS bucket,
    machine_id,
    sensor_id,
    AVG(value)    AS avg_value,
    MIN(value)    AS min_value,
    MAX(value)    AS max_value,
    STDDEV(value) AS stddev_value,
    COUNT(*)      AS reading_count
FROM telemetry
GROUP BY bucket, machine_id, sensor_id
WITH NO DATA;

SELECT add_retention_policy('telemetry', INTERVAL '90 days', if_not_exists => TRUE);

-- ══════════════════════════════════════════════════════════════════
-- Ingestion quality
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS dead_letter (
    id          BIGSERIAL PRIMARY KEY,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload     JSONB       NOT NULL,
    reason      VARCHAR(64) NOT NULL
);

-- ══════════════════════════════════════════════════════════════════
-- ML features + model outputs
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS features (
    ts           TIMESTAMPTZ      NOT NULL,
    machine_id   VARCHAR(50)      NOT NULL,
    feature_name VARCHAR(64)      NOT NULL,
    value        DOUBLE PRECISION NOT NULL
);

SELECT create_hypertable('features', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_features_machine_name_ts ON features (machine_id, feature_name, ts DESC);

CREATE TABLE IF NOT EXISTS predictions (
    id              BIGSERIAL PRIMARY KEY,
    machine_id      VARCHAR(50) NOT NULL REFERENCES machines(id),
    ts              TIMESTAMPTZ NOT NULL DEFAULT now(),
    anomaly_score   DOUBLE PRECISION,
    rul_cycles      DOUBLE PRECISION,
    failure_class   VARCHAR(64),
    failure_probs   JSONB,
    model_versions  JSONB
);

CREATE INDEX IF NOT EXISTS idx_predictions_machine_ts ON predictions (machine_id, ts DESC);

-- ══════════════════════════════════════════════════════════════════
-- Alerting + health
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS alerts (
    id             VARCHAR(64) PRIMARY KEY,
    machine_id     VARCHAR(50) NOT NULL REFERENCES machines(id),
    severity       VARCHAR(16) NOT NULL CHECK (severity IN ('info', 'warn', 'critical')),
    fault_type     VARCHAR(64),
    opened_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at      TIMESTAMPTZ,
    model_snapshot JSONB,
    status         VARCHAR(16) NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open', 'acked', 'resolved')),
    acked_by       VARCHAR(64)
);

CREATE INDEX IF NOT EXISTS idx_alerts_machine_status ON alerts (machine_id, status);
CREATE INDEX IF NOT EXISTS idx_alerts_opened_at ON alerts (opened_at);

CREATE TABLE IF NOT EXISTS health_scores (
    ts           TIMESTAMPTZ      NOT NULL,
    machine_id   VARCHAR(50)      NOT NULL,
    score        DOUBLE PRECISION NOT NULL CHECK (score >= 0 AND score <= 100),
    breakdown    JSONB
);

SELECT create_hypertable('health_scores', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_health_scores_machine_ts ON health_scores (machine_id, ts DESC);

-- ══════════════════════════════════════════════════════════════════
-- Copilot output
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS work_orders (
    id           VARCHAR(64) PRIMARY KEY,
    alert_id     VARCHAR(64) NOT NULL REFERENCES alerts(id),
    draft_md     TEXT        NOT NULL,
    citations    JSONB,
    status       VARCHAR(16) NOT NULL DEFAULT 'draft'
                 CHECK (status IN ('draft', 'approved', 'rejected')),
    approved_by  VARCHAR(64),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ══════════════════════════════════════════════════════════════════
-- Users + audit
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
    id            VARCHAR(64) PRIMARY KEY,
    username      VARCHAR(64) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(16) NOT NULL
                  CHECK (role IN ('technician', 'engineer', 'manager', 'data_scientist', 'admin')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_log (
    id          BIGSERIAL PRIMARY KEY,
    user_id     VARCHAR(64) REFERENCES users(id),
    action      VARCHAR(64) NOT NULL,
    entity_type VARCHAR(64),
    entity_id   VARCHAR(64),
    at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    detail      JSONB
);

-- ══════════════════════════════════════════════════════════════════
-- MLOps
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS drift_reports (
    id           BIGSERIAL PRIMARY KEY,
    machine_id   VARCHAR(50) REFERENCES machines(id),
    feature_name VARCHAR(64) NOT NULL,
    metric       VARCHAR(8)  NOT NULL CHECK (metric IN ('PSI', 'KS')),
    value        DOUBLE PRECISION NOT NULL,
    breached     BOOLEAN NOT NULL DEFAULT false,
    computed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

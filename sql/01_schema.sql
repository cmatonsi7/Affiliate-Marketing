-- ============================================================
-- Affiliate Partner Performance — PostgreSQL Schema
-- Star schema: dim_partner, dim_campaign + fact_performance
-- ============================================================

DROP SCHEMA IF EXISTS raw CASCADE;
DROP SCHEMA IF EXISTS analytics CASCADE;

CREATE SCHEMA raw;
CREATE SCHEMA analytics;

-- ------------------------------------------------------------
-- RAW landing table — mirrors the source CSV exactly (all text)
-- so nothing is lost or silently coerced on load.
-- ------------------------------------------------------------
CREATE TABLE raw.affiliate_performance_raw (
    row_id              TEXT,
    partner_id          TEXT,
    partner_name        TEXT,
    partner_type        TEXT,
    click_date          TEXT,
    clicks              TEXT,
    conversions         TEXT,
    revenue             TEXT,
    commission_paid     TEXT,
    campaign            TEXT,
    device_type         TEXT,
    region              TEXT
);

-- ------------------------------------------------------------
-- MASTER DATASET: dim_partner
-- One row per partner. Deduplicated + cleaned from raw.
-- ------------------------------------------------------------
CREATE TABLE analytics.dim_partner (
    partner_id      VARCHAR(10) PRIMARY KEY,
    partner_name    VARCHAR(100) NOT NULL,
    partner_type    VARCHAR(50)
);

-- ------------------------------------------------------------
-- MASTER DATASET: dim_campaign
-- ------------------------------------------------------------
CREATE TABLE analytics.dim_campaign (
    campaign_id     SERIAL PRIMARY KEY,
    campaign_name   VARCHAR(100) UNIQUE NOT NULL
);

-- ------------------------------------------------------------
-- FACT TABLE: fact_performance
-- Grain: one row per (partner, campaign, click_date, device, region)
-- performance record, matching the source data grain.
-- ------------------------------------------------------------
CREATE TABLE analytics.fact_performance (
    fact_id             SERIAL PRIMARY KEY,
    source_row_id        INTEGER,
    partner_id           VARCHAR(10) REFERENCES analytics.dim_partner(partner_id),
    campaign_id           INTEGER REFERENCES analytics.dim_campaign(campaign_id),
    click_date            DATE NOT NULL,
    clicks                 INTEGER CHECK (clicks >= 0),
    conversions             INTEGER CHECK (conversions >= 0),
    revenue                  NUMERIC(12,2) CHECK (revenue >= 0),
    commission_paid            NUMERIC(12,2) CHECK (commission_paid >= 0),
    device_type                 VARCHAR(20),
    region                        VARCHAR(10),
    loaded_at                      TIMESTAMP DEFAULT now()
);

-- ------------------------------------------------------------
-- QUARANTINE table — rows that failed validation during
-- cleaning are moved here with a reason, never silently dropped.
-- (Mirrors the quarantine pattern already used in the
-- Phase 4 E-Commerce Pipeline project.)
-- ------------------------------------------------------------
CREATE TABLE analytics.performance_quarantine (
    source_row_id       INTEGER,
    quarantine_reason    TEXT,
    raw_data               JSONB,
    quarantined_at            TIMESTAMP DEFAULT now()
);

-- ------------------------------------------------------------
-- Indexes to support the analytical query patterns below
-- ------------------------------------------------------------
CREATE INDEX idx_fact_partner_id   ON analytics.fact_performance(partner_id);
CREATE INDEX idx_fact_click_date   ON analytics.fact_performance(click_date);
CREATE INDEX idx_fact_campaign_id  ON analytics.fact_performance(campaign_id);
CREATE INDEX idx_fact_region       ON analytics.fact_performance(region);

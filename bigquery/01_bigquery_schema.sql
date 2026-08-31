-- ============================================================
-- Affiliate Partner Performance — BigQuery Schema
-- ============================================================

CREATE SCHEMA IF NOT EXISTS `affiliate-analytics-portfolio`;

CREATE OR REPLACE TABLE `affiliate-analytics-portfolio.affiliate_analytics.dim_partner` (
    partner_id      STRING NOT NULL,
    partner_name    STRING NOT NULL,
    partner_type    STRING
);

CREATE OR REPLACE TABLE `affiliate-analytics-portfolio.affiliate_analytics.dim_campaign` (
    campaign_id     INT64 NOT NULL,
    campaign_name   STRING NOT NULL
);

-- Partitioned + clustered fact table — this is the BigQuery-specific
-- piece that has no Postgres equivalent: partitioning by date keeps
-- queries that filter on click_date cheap by only scanning relevant
-- partitions, and clustering by partner_id speeds up per-partner
-- aggregations (exactly the query pattern in 02_business_queries.sql).
CREATE OR REPLACE TABLE `affiliate-analytics-portfolio.affiliate_analytics.fact_performance` (
    source_row_id     INT64,
    partner_id        STRING,
    campaign_id       INT64,
    click_date        DATE,
    clicks            INT64,
    conversions       INT64,
    revenue           NUMERIC,
    commission_paid   NUMERIC,
    device_type       STRING,
    region            STRING
)
PARTITION BY click_date
CLUSTER BY partner_id;

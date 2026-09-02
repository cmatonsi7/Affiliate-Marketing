

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

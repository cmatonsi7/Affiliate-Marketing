# Affiliate Partner Performance — Multi-Platform Analytics Pipeline

One dataset, three platforms: **PostgreSQL** (relational warehouse) →
**BigQuery** (cloud data warehouse) → **Looker Studio** (BI dashboard).
Mirrors the actual data analyst workflow of extracting from a relational
source, modeling it in a cloud warehouse, and building self-service
dashboards for stakeholders.

| Stage | Folder | What it shows |
|---|---|---|
| 1. Relational warehouse | `sql/`, `scripts/` | Star schema design, data cleaning, quarantine pattern, PostgreSQL |
| 2. Cloud data warehouse | `bigquery/` | Same schema migrated to BigQuery, partitioning/clustering, GCP setup |
| 3. BI dashboard | `looker/` | Interactive Looker Studio report on top of BigQuery |

Business analysis of a 20-partner affiliate marketing program, rebuilt on a
production-style relational database (PostgreSQL) with a proper star schema,
data quality quarantine pattern, and analytical SQL — instead of processing
everything in memory with Pandas/DuckDB.

This project takes the raw affiliate performance data and answers the same
question the [Partner Health Check](../affiliate-revenue-trend-analysis)
project does — *which partners are at risk and where is program revenue
concentrated* — but does the extraction, cleaning, and analysis entirely in
SQL against a relational warehouse, mirroring how a data analyst would work
against a real production database (mySQL/PostgreSQL) rather than flat files.

## Why this project exists

Most of my earlier portfolio work uses DuckDB/SQLite and Pandas. This project
specifically demonstrates:
- Designing a **star schema** (master dimension tables + fact table) rather
  than a single flat table
- **PostgreSQL** as the target database — the RDBMS most commonly named in
  data analyst job descriptions
- A **data quality quarantine pattern**: invalid rows are never silently
  dropped, they're logged with a reason and preserved for review
- **Indexed, production-style schema design** (primary keys, foreign keys,
  check constraints, indexes on query columns)

## Data

Source: `data/raw_affiliate_partner_performance.csv` — 580 rows of daily
affiliate performance data across 20 partners (Jan 2025–Jun 2026), with
realistic data quality issues:

| Issue | Detail |
|---|---|
| Mixed date formats | 3 formats in the same column: `MM/DD/YYYY`, `YYYY-MM-DD`, `DD-MM-YYYY` |
| Currency-formatted strings | `revenue`/`commission_paid` mix plain floats (`8518.87`) with currency strings (`$18,436.14`) |
| Scattered nulls | Missing values across `partner_type`, `device_type`, `region`, `revenue`, `commission_paid` |
| Fully invalid rows | A small number of rows missing partner identity or an unparseable date |

## Architecture

```
raw_affiliate_partner_performance.csv
        │
        ▼
raw.affiliate_performance_raw   (landing table, unmodified, all-text)
        │
        ▼  Python ETL (scripts/load_to_postgres.py)
        │  - parse 3 mixed date formats
        │  - strip currency formatting ($, commas)
        │  - validate types, drop-nothing-silently
        │
        ├──► analytics.dim_partner            (master dataset, 20 partners)
        ├──► analytics.dim_campaign           (master dataset, 6 campaigns)
        ├──► analytics.fact_performance       (560 clean rows)
        └──► analytics.performance_quarantine (20 quarantined rows + reason)
```

See `docs/schema.png` (or the ERD in this repo) for the full star schema.

## Setup

```bash
createdb affiliate_analytics
psql -d affiliate_analytics -f sql/01_schema.sql
python3 scripts/load_to_postgres.py
psql -d affiliate_analytics -f sql/02_business_queries.sql
```

## Load results

| Metric | Value |
|---|---|
| Raw rows read | 580 |
| Clean rows loaded to `fact_performance` | 560 |
| Rows quarantined | 20 |
| Unique partners (`dim_partner`) | 20 |
| Unique campaigns (`dim_campaign`) | 6 |

## Business queries (`sql/02_business_queries.sql`)

1. **Partner health segmentation** — first-half vs second-half average
   monthly revenue per partner, classified At Risk / Stagnant / Growing
2. **Revenue concentration risk** — % of total program revenue held by
   each partner
3. **Campaign effectiveness by device & region** — clicks, conversions,
   conversion rate, revenue, commission
4. **Partner-type ROI** — revenue generated per Rand of commission paid,
   by partner type
5. **Data quality / validation report** — breakdown of quarantined rows
   by failure reason
6. **Monthly program-wide trend** — revenue, clicks, conversions,
   conversion rate over time

## Key findings

Running the same trend-segmentation logic in SQL against Postgres reproduces
the original finding: **10 of 20 partners are trending down** in second-half
average monthly revenue vs first-half, while 9 are growing and 1 is flat —
consistent with the original DuckDB/Pandas analysis, now running against a
relational warehouse with enforced schema constraints and full data lineage
via the raw landing table.

## Tech

PostgreSQL 16 | Python | psycopg2 | Pandas (cleaning only, not analysis) | SQL

## Next steps

The same cleaned data feeds four companion pieces in this repo:
- **`bigquery/`** — same star schema migrated to BigQuery, partitioned by
  `click_date` and clustered by `partner_id`. See `bigquery/SETUP_GUIDE.md`
  for a from-zero walkthrough.
- **`looker/`** — interactive Looker Studio dashboard built on the BigQuery
  data. See `looker/BUILD_GUIDE.md`.
- **`forecasting/`** — 3-month revenue forecast by partner type, comparing
  moving average vs linear regression with a backtested accuracy
  comparison. See `forecasting/FORECASTING_NOTES.md`.
- **`pyspark/`** — the health segmentation query reproduced using the
  PySpark DataFrame API instead of SQL/pandas, for light exposure to the
  Spark API. See `pyspark/RUN_IN_COLAB.md`.

See `docs/MARTECH_CONTEXT.md` for the business/domain reasoning behind the
segmentation and forecasting approach — why partner type matters, why
revenue concentration risk drives retention prioritization, and what this
project does and doesn't demonstrate about MarTech industry experience.

## Multi-platform pipeline — status

| Platform | Status | Detail |
|---|---|---|
| PostgreSQL | ✅ Built & verified | 580 raw rows → 560 clean, 20 quarantined, star schema, 6 business queries |
| BigQuery | ✅ Built & verified | Same 20 partners / 6 campaigns / 560 fact rows, partitioned + clustered, health segmentation query reproduces Postgres output exactly |
| Google Looker Studio | ✅ Built & verified | Interactive dashboard on top of BigQuery — see `looker/` |
| Forecasting | ✅ Built & verified | 3-month revenue forecast by partner type, moving average vs linear regression, backtested — see `forecasting/` |
| PySpark | ✅ Built & verified | Health segmentation reproduced in PySpark DataFrame API, matches Postgres/BigQuery exactly (10/9/1) — see `pyspark/` |

All three platforms show identical numbers (20 partners, 10 At Risk, 8
Growing, 2 Stagnant), because they're one dataset flowing through one
pipeline rather than three disconnected examples.

### Dashboard

The Looker Studio dashboard (kept private — screenshot below for portfolio
purposes) includes:
- 4 scorecards (Total Partners, At Risk, Growing, Stagnant)
- A partner-level bar chart of revenue trend % change, conditionally
  colored red (declining) / blue (growing)
- A donut chart summarizing the same three-way health split
- A `partner_type` filter control for stakeholder self-service

`![Dashboard screenshot](looker/screenshots/dashboard.png)`
*(add your saved screenshot to `looker/screenshots/dashboard.png` before
pushing to GitHub)*

### Notes from building this (real troubleshooting encountered)

- **BigQuery schema auto-detection fails on all-string CSVs.** Loading
  `dim_partner.csv` (three STRING columns, no numeric/date columns to
  anchor against) repeatedly caused BigQuery's auto-detect to treat the
  header row as data and assign generic `string_field_N` column names.
  Fixed by disabling auto-detect and defining the schema manually
  (`partner_id:STRING,partner_name:STRING,partner_type:STRING`) alongside
  "Header rows to skip = 1". Auto-detect worked fine on tables that mixed
  in INT64/DATE/FLOAT64 columns.
- **Looker Studio page-level filters apply globally, not per-chart.**
  A `partner_name` filter chip left over from testing silently scoped every
  chart and scorecard on the page down to a single partner, producing
  numbers that didn't reconcile (e.g. At Risk/Growing/Stagnant not summing
  to 20). Cleared via the filter chip at the top of the page.
- **Custom-query data sources inherit useful field names automatically** —
  Looker Studio named the BigQuery custom query's data source after the
  underlying table (`fact_performance`) even though it's really a
  pre-aggregated 20-row result, which is worth knowing when debugging which
  data source a chart is actually pointed at.

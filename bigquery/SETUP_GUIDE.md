# BigQuery Setup Guide — From Zero

This walks you through getting this project running on your own Google Cloud
account. Total time: ~20-30 minutes. Cost: $0 — everything here fits inside
the free tier (1TB of query processing/month, 10GB storage/month, no credit
card charges as long as you stay under those limits, which this project does
by a huge margin — the whole dataset is <1MB).

## 1. Create a Google Cloud account — use Sandbox mode, skip the trial

**Important: don't click "Try Google Cloud for free."** That flow asks for a
$30 refundable prepayment in some countries (South Africa included) before
it activates. You don't need it.

Instead, use **BigQuery Sandbox** — a no-billing-account-required mode with
its own free limits (10GB storage, 1TB query processing/month, no streaming
inserts). Our dataset is under 1MB, so this is more than enough:

1. Go to https://console.cloud.google.com
2. Sign in with a Google account (or create one)
3. If you land on a "Try for free" or payment page, **do not enter payment
   details** — instead, close that flow and go directly to
   https://console.cloud.google.com/bigquery
4. BigQuery will prompt you to create a project. Do that — no billing
   account is required for this.
5. Once in the BigQuery console, you're automatically in Sandbox mode if no
   billing is linked. You'll see a small "Sandbox" indicator/banner in the
   console confirming this.

## 2. Create a project

1. Click the project dropdown at the top of the console → **New Project**
2. Name it something like `affiliate-analytics-portfolio`
3. Note the **Project ID** shown (not the name — the ID, e.g.
   `affiliate-analytics-portfolio-123456`) — you'll need this to replace
   `affiliate-analytics-portfolio` in every SQL file in this folder.

## 3. Enable the BigQuery API

1. In the console search bar, type "BigQuery" and open it
2. If prompted, click **Enable API** (usually already enabled by default)

## 4. Create the dataset

You can do this via the console UI or by running the schema SQL directly —
running the SQL is faster and is itself something you can screenshot as
evidence of the work.

1. Open the **BigQuery** page in the console
2. In the Explorer panel, click your project → click the 3-dot menu →
   **Create dataset**
   - Dataset ID: `affiliate_analytics`
   - Location: `US` (or your nearest region)
3. Open the **Query editor**, paste the contents of
   `01_bigquery_schema.sql`, replace `affiliate-analytics-portfolio` with your actual
   project ID, and click **Run**.

## 5. Load the cleaned data

The `clean_data/` folder in this project already has the cleaned CSVs
exported straight from the Postgres build — no need to re-clean anything in
BigQuery, you're loading a trusted, already-validated dataset (this is a
legitimate real-world pattern: BigQuery as a downstream analytics warehouse
fed by an upstream operational database).

For each table:

1. In the Explorer panel, click on your dataset → **Create table**
2. Source: **Upload** → select the matching CSV from `clean_data/`
3. Destination table: `dim_partner`, `dim_campaign`, or `fact_performance`
   (matching the CSV name)
4. Schema: toggle **Auto detect** ON for the dimension tables. For
   `fact_performance`, turn auto-detect OFF and instead use **Edit as text**,
   pasting in the schema from `01_bigquery_schema.sql` (this guarantees
   `revenue`/`commission_paid` load as NUMERIC, not FLOAT — auto-detect
   sometimes gets this wrong).
5. Click **Create table**

Repeat for all three CSVs.

## 6. Verify the load

Run this in the query editor (replace `affiliate-analytics-portfolio`):

```sql
SELECT
  (SELECT COUNT(*) FROM `affiliate-analytics-portfolio.affiliate_analytics.dim_partner`) AS partners,
  (SELECT COUNT(*) FROM `affiliate-analytics-portfolio.affiliate_analytics.dim_campaign`) AS campaigns,
  (SELECT COUNT(*) FROM `affiliate-analytics-portfolio.affiliate_analytics.fact_performance`) AS fact_rows;
```

Expected result: `partners=20, campaigns=6, fact_rows=560`.

## 7. Run the business queries

Open `02_bigquery_business_queries.sql`, replace `affiliate-analytics-portfolio`
throughout (find-and-replace works fine), and run each query block in the
BigQuery console one at a time. Screenshot the results — these screenshots
are your evidence for the CV/GitHub README, since I can't execute these
against live BigQuery from this environment.

## 8. What to capture as evidence for your CV/GitHub

- Screenshot of the dataset + tables in the Explorer panel
- Screenshot of query 1 (partner health segmentation) results
- Screenshot of the "bytes processed" indicator BigQuery shows before you
  run a query — this shows you understand BigQuery's on-demand pricing model
- A short note in your repo README: "Migrated the same star schema from
  PostgreSQL to BigQuery, including partitioning by click_date and
  clustering by partner_id to optimize query cost"

## Honest framing for your CV

This gives you **legitimate, hands-on BigQuery experience** — you designed
the schema, loaded real data, and ran analytical SQL against it. It is
**not** the same as production experience with Kudu/Impala/SingleStore/Hive
(those require infrastructure you can't reasonably self-provision), so don't
claim those. "Extracted and analyzed data in Google BigQuery using SQL" is
accurate. "Experience with big data technologies including Kudu and Impala"
would not be.

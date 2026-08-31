-- ============================================================
-- Business queries — Affiliate Partner Performance (PostgreSQL)
-- Each query maps to a responsibility from the target JD.
-- ============================================================

-- 1. PARTNER HEALTH SEGMENTATION
-- (mirrors "use statistical techniques to identify trends")
-- First-half vs second-half average monthly revenue per partner,
-- segmented into At Risk / Stagnant / Growing.
WITH monthly_revenue AS (
    SELECT
        partner_id,
        date_trunc('month', click_date) AS month,
        SUM(revenue) AS monthly_revenue
    FROM analytics.fact_performance
    GROUP BY partner_id, date_trunc('month', click_date)
),
halves AS (
    SELECT
        partner_id,
        AVG(monthly_revenue) FILTER (
            WHERE month < (SELECT min(month) + (max(month) - min(month)) / 2 FROM monthly_revenue)
        ) AS first_half_avg,
        AVG(monthly_revenue) FILTER (
            WHERE month >= (SELECT min(month) + (max(month) - min(month)) / 2 FROM monthly_revenue)
        ) AS second_half_avg
    FROM monthly_revenue
    GROUP BY partner_id
)
SELECT
    p.partner_id,
    p.partner_name,
    p.partner_type,
    round(h.first_half_avg, 2)  AS first_half_avg_monthly_revenue,
    round(h.second_half_avg, 2) AS second_half_avg_monthly_revenue,
    round(100.0 * (h.second_half_avg - h.first_half_avg) / NULLIF(h.first_half_avg, 0), 1) AS pct_change,
    CASE
        WHEN h.second_half_avg < h.first_half_avg * 0.9 THEN 'At Risk'
        WHEN h.second_half_avg > h.first_half_avg * 1.1 THEN 'Growing'
        ELSE 'Stagnant'
    END AS health_segment
FROM halves h
JOIN analytics.dim_partner p ON p.partner_id = h.partner_id
ORDER BY pct_change ASC;


-- 2. REVENUE CONCENTRATION RISK
-- (mirrors "help identify business logic embedded in datasets" +
--  ad-hoc KPI analysis)
-- What share of total revenue sits with declining partners?
WITH partner_totals AS (
    SELECT partner_id, SUM(revenue) AS total_revenue
    FROM analytics.fact_performance
    GROUP BY partner_id
),
grand_total AS (
    SELECT SUM(total_revenue) AS total FROM partner_totals
)
SELECT
    p.partner_name,
    p.partner_type,
    pt.total_revenue,
    round(100.0 * pt.total_revenue / g.total, 1) AS pct_of_program_revenue
FROM partner_totals pt
JOIN analytics.dim_partner p ON p.partner_id = pt.partner_id
CROSS JOIN grand_total g
ORDER BY pt.total_revenue DESC;


-- 3. CAMPAIGN EFFECTIVENESS BY DEVICE & REGION
-- (mirrors "build dashboards/reports for business stakeholders")
SELECT
    c.campaign_name,
    f.device_type,
    f.region,
    SUM(f.clicks)        AS total_clicks,
    SUM(f.conversions)   AS total_conversions,
    round(100.0 * SUM(f.conversions) / NULLIF(SUM(f.clicks), 0), 2) AS conversion_rate_pct,
    SUM(f.revenue)        AS total_revenue,
    SUM(f.commission_paid) AS total_commission
FROM analytics.fact_performance f
JOIN analytics.dim_campaign c ON c.campaign_id = f.campaign_id
GROUP BY c.campaign_name, f.device_type, f.region
ORDER BY total_revenue DESC
LIMIT 20;


-- 4. PARTNER TYPE ROI (commission cost vs revenue generated)
-- (mirrors "analyze source systems... assess KPIs")
SELECT
    p.partner_type,
    COUNT(DISTINCT p.partner_id) AS num_partners,
    SUM(f.revenue)               AS total_revenue,
    SUM(f.commission_paid)       AS total_commission_paid,
    round(SUM(f.revenue) / NULLIF(SUM(f.commission_paid), 0), 2) AS revenue_per_commission_rand
FROM analytics.fact_performance f
JOIN analytics.dim_partner p ON p.partner_id = f.partner_id
GROUP BY p.partner_type
ORDER BY total_revenue DESC;


-- 5. DATA QUALITY / VALIDATION REPORT
-- (mirrors "identify and communicate data quality and
--  data validation issues in productionalized datasets")
SELECT
    quarantine_reason,
    COUNT(*) AS num_rows
FROM analytics.performance_quarantine
GROUP BY quarantine_reason
ORDER BY num_rows DESC;


-- 6. MONTHLY PROGRAM-WIDE TREND (for the "not self-correcting" finding)
SELECT
    date_trunc('month', click_date)::date AS month,
    SUM(revenue) AS total_revenue,
    SUM(clicks) AS total_clicks,
    SUM(conversions) AS total_conversions,
    round(100.0 * SUM(conversions) / NULLIF(SUM(clicks), 0), 2) AS conversion_rate_pct
FROM analytics.fact_performance
GROUP BY date_trunc('month', click_date)
ORDER BY month;

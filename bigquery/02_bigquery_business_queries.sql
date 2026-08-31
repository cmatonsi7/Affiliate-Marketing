-- ============================================================
-- Business queries — Affiliate Partner Performance (BigQuery)
-- ============================================================

-- 1. PARTNER HEALTH SEGMENTATION
WITH monthly_revenue AS (
    SELECT
        partner_id,
        DATE_TRUNC(click_date, MONTH) AS month,
        SUM(revenue) AS monthly_revenue
    FROM `affiliate-analytics-portfolio.affiliate_analytics.fact_performance`
    GROUP BY partner_id, DATE_TRUNC(click_date, MONTH)
),
bounds AS (
    SELECT
        MIN(month) AS min_month,
        DATE_ADD(MIN(month), INTERVAL DIV(DATE_DIFF(MAX(month), MIN(month), MONTH), 2) MONTH) AS midpoint
    FROM monthly_revenue
),
halves AS (
    SELECT
        m.partner_id,
        AVG(IF(m.month < b.midpoint, m.monthly_revenue, NULL)) AS first_half_avg,
        AVG(IF(m.month >= b.midpoint, m.monthly_revenue, NULL)) AS second_half_avg
    FROM monthly_revenue m
    CROSS JOIN bounds b
    GROUP BY m.partner_id
)
SELECT
    p.partner_id,
    p.partner_name,
    p.partner_type,
    ROUND(h.first_half_avg, 2)  AS first_half_avg_monthly_revenue,
    ROUND(h.second_half_avg, 2) AS second_half_avg_monthly_revenue,
    ROUND(100.0 * (h.second_half_avg - h.first_half_avg) / NULLIF(h.first_half_avg, 0), 1) AS pct_change,
    CASE
        WHEN h.second_half_avg < h.first_half_avg * 0.9 THEN 'At Risk'
        WHEN h.second_half_avg > h.first_half_avg * 1.1 THEN 'Growing'
        ELSE 'Stagnant'
    END AS health_segment
FROM halves h
JOIN `affiliate-analytics-portfolio.affiliate_analytics.dim_partner` p ON p.partner_id = h.partner_id
ORDER BY pct_change ASC;


-- 2. REVENUE CONCENTRATION RISK
WITH partner_totals AS (
    SELECT partner_id, SUM(revenue) AS total_revenue
    FROM `affiliate-analytics-portfolio.affiliate_analytics.fact_performance`
    GROUP BY partner_id
),
grand_total AS (
    SELECT SUM(total_revenue) AS total FROM partner_totals
)
SELECT
    p.partner_name,
    p.partner_type,
    pt.total_revenue,
    ROUND(100.0 * pt.total_revenue / g.total, 1) AS pct_of_program_revenue
FROM partner_totals pt
JOIN `affiliate-analytics-portfolio.affiliate_analytics.dim_partner` p ON p.partner_id = pt.partner_id
CROSS JOIN grand_total g
ORDER BY pt.total_revenue DESC;


-- 3. CAMPAIGN EFFECTIVENESS BY DEVICE & REGION
SELECT
    c.campaign_name,
    f.device_type,
    f.region,
    SUM(f.clicks)        AS total_clicks,
    SUM(f.conversions)   AS total_conversions,
    ROUND(100.0 * SUM(f.conversions) / NULLIF(SUM(f.clicks), 0), 2) AS conversion_rate_pct,
    SUM(f.revenue)        AS total_revenue,
    SUM(f.commission_paid) AS total_commission
FROM `affiliate-analytics-portfolio.affiliate_analytics.fact_performance` f
JOIN `affiliate-analytics-portfolio.affiliate_analytics.dim_campaign` c ON c.campaign_id = f.campaign_id
GROUP BY c.campaign_name, f.device_type, f.region
ORDER BY total_revenue DESC
LIMIT 20;


-- 4. PARTNER TYPE ROI
SELECT
    p.partner_type,
    COUNT(DISTINCT p.partner_id) AS num_partners,
    SUM(f.revenue)               AS total_revenue,
    SUM(f.commission_paid)       AS total_commission_paid,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.commission_paid), 0), 2) AS revenue_per_commission_rand
FROM `affiliate-analytics-portfolio.affiliate_analytics.fact_performance` f
JOIN `affiliate-analytics-portfolio.affiliate_analytics.dim_partner` p ON p.partner_id = f.partner_id
GROUP BY p.partner_type
ORDER BY total_revenue DESC;


-- 5. MONTHLY PROGRAM-WIDE TREND
SELECT
    DATE_TRUNC(click_date, MONTH) AS month,
    SUM(revenue) AS total_revenue,
    SUM(clicks) AS total_clicks,
    SUM(conversions) AS total_conversions,
    ROUND(100.0 * SUM(conversions) / NULLIF(SUM(clicks), 0), 2) AS conversion_rate_pct
FROM `affiliate-analytics-portfolio.affiliate_analytics.fact_performance`
GROUP BY DATE_TRUNC(click_date, MONTH)
ORDER BY month;



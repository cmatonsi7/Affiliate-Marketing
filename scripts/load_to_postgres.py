

import json
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

RAW_CSV = "/content/affiliate-postgres-project/data/raw_affiliate_partner_performance.csv"
DB_CONFIG = dict(
    host="localhost",
    dbname="affiliate_analytics",
    user="postgres",
    password="postgres",
)


def parse_mixed_date(value):
    """Try the 3 known source formats in order; return None if none match."""
    if pd.isna(value):
        return None
    value = str(value).strip()
    for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%d-%m-%Y"):
        try:
            return pd.to_datetime(value, format=fmt).date()
        except ValueError:
            continue
    return None  # unparseable -> quarantine


def clean_currency(value):
    """Strip $ and , from currency strings, return float or None."""
    if pd.isna(value):
        return None
    value = str(value).replace("$", "").replace(",", "").strip()
    try:
        return float(value)
    except ValueError:
        return None


def main():
    print("Reading raw CSV...")
    df = pd.read_csv(RAW_CSV)
    n_raw = len(df)
    print(f"  {n_raw} raw rows")

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    print("Loading raw landing table (raw.affiliate_performance_raw)...")
    cur.execute("TRUNCATE raw.affiliate_performance_raw")
    raw_records = df.astype(object).where(pd.notnull(df), None).values.tolist()
    execute_values(
        cur,
        """INSERT INTO raw.affiliate_performance_raw
           (row_id, partner_id, partner_name, partner_type, click_date,
            clicks, conversions, revenue, commission_paid, campaign,
            device_type, region)
           VALUES %s""",
        raw_records,
    )
    conn.commit()

    print("Cleaning...")
    clean_rows = []
    quarantined = []

    for _, row in df.iterrows():
        reasons = []

        partner_id = row.get("partner_id")
        partner_name = row.get("partner_name")
        partner_type = row.get("partner_type")
        campaign = row.get("campaign")

        if pd.isna(partner_id) or pd.isna(partner_name):
            reasons.append("missing partner_id/partner_name")

        parsed_date = parse_mixed_date(row.get("click_date"))
        if parsed_date is None:
            reasons.append("unparseable click_date")

        try:
            clicks = int(float(row.get("clicks"))) if pd.notna(row.get("clicks")) else None
        except (ValueError, TypeError):
            clicks = None
        if clicks is None:
            reasons.append("invalid clicks")

        try:
            conversions = int(float(row.get("conversions"))) if pd.notna(row.get("conversions")) else None
        except (ValueError, TypeError):
            conversions = None
        if conversions is None:
            reasons.append("invalid conversions")

        revenue = clean_currency(row.get("revenue"))
        commission = clean_currency(row.get("commission_paid"))
        if revenue is None:
            reasons.append("invalid/missing revenue")
        if commission is None:
            reasons.append("invalid/missing commission_paid")

        device_type = row.get("device_type") if pd.notna(row.get("device_type")) else "Unknown"
        region = row.get("region") if pd.notna(row.get("region")) else "Unknown"
        partner_type = partner_type if pd.notna(partner_type) else "Unknown"
        campaign = campaign if pd.notna(campaign) else "Unknown"

        if reasons:
            quarantined.append(
                {
                    "source_row_id": int(row["row_id"]) if pd.notna(row.get("row_id")) else None,
                    "reason": "; ".join(reasons),
                    "raw": row.where(pd.notnull(row), None).to_dict(),
                }
            )
            continue

        clean_rows.append(
            dict(
                source_row_id=int(row["row_id"]),
                partner_id=partner_id,
                partner_name=partner_name,
                partner_type=partner_type,
                campaign=campaign,
                click_date=parsed_date,
                clicks=clicks,
                conversions=conversions,
                revenue=revenue,
                commission_paid=commission,
                device_type=device_type,
                region=region,
            )
        )

    print(f"  {len(clean_rows)} clean rows, {len(quarantined)} quarantined")

    partners = {
        r["partner_id"]: (r["partner_id"], r["partner_name"], r["partner_type"])
        for r in clean_rows
    }
    print(f"Loading dim_partner ({len(partners)} unique partners)...")
    cur.execute("TRUNCATE analytics.dim_partner CASCADE")
    execute_values(
        cur,
        "INSERT INTO analytics.dim_partner (partner_id, partner_name, partner_type) VALUES %s",
        list(partners.values()),
    )
    conn.commit()

    campaigns = sorted({r["campaign"] for r in clean_rows})
    print(f"Loading dim_campaign ({len(campaigns)} campaigns)...")
    cur.execute("TRUNCATE analytics.dim_campaign CASCADE")
    execute_values(
        cur,
        "INSERT INTO analytics.dim_campaign (campaign_name) VALUES %s",
        [(c,) for c in campaigns],
    )
    conn.commit()

    cur.execute("SELECT campaign_name, campaign_id FROM analytics.dim_campaign")
    campaign_id_map = dict(cur.fetchall())

    print(f"Loading fact_performance ({len(clean_rows)} rows)...")
    fact_records = [
        (
            r["source_row_id"],
            r["partner_id"],
            campaign_id_map[r["campaign"]],
            r["click_date"],
            r["clicks"],
            r["conversions"],
            r["revenue"],
            r["commission_paid"],
            r["device_type"],
            r["region"],
        )
        for r in clean_rows
    ]
    execute_values(
        cur,
        """INSERT INTO analytics.fact_performance
           (source_row_id, partner_id, campaign_id, click_date, clicks,
            conversions, revenue, commission_paid, device_type, region)
           VALUES %s""",
        fact_records,
    )
    conn.commit()

    if quarantined:
        print(f"Loading performance_quarantine ({len(quarantined)} rows)...")
        q_records = [
            (q["source_row_id"], q["reason"], json.dumps(q["raw"]))
            for q in quarantined
        ]
        execute_values(
            cur,
            """INSERT INTO analytics.performance_quarantine
               (source_row_id, quarantine_reason, raw_data) VALUES %s""",
            q_records,
        )
        conn.commit()

    print("\n=== LOAD SUMMARY ===")
    print(f"Raw rows read:        {n_raw}")
    print(f"Clean rows loaded:    {len(clean_rows)}")
    print(f"Quarantined rows:     {len(quarantined)}")
    print(f"Unique partners:      {len(partners)}")
    print(f"Unique campaigns:     {len(campaigns)}")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()

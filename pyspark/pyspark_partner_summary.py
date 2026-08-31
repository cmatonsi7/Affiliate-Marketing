

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("AffiliatePartnerSummary").getOrCreate()
fact = spark.read.csv("/content/fact_performance.csv", header=True, inferSchema=True)
partners = spark.read.csv("/content/dim_partner.csv", header=True, inferSchema=True)

print(f"Loaded {fact.count()} fact rows, {partners.count()} partners")


monthly = (
    fact
    .withColumn("month", F.date_trunc("month", F.col("click_date")))
    .groupBy("partner_id", "month")
    .agg(F.sum("revenue").alias("monthly_revenue"))
)

bounds = monthly.agg(
    F.min("month").alias("min_month"), F.max("month").alias("max_month")
).collect()[0]

midpoint = bounds["min_month"] + (
    (bounds["max_month"] - bounds["min_month"]) / 2
)

monthly = monthly.withColumn(
    "half", F.when(F.col("month") < F.lit(midpoint), "first").otherwise("second")
)

halves = (
    monthly.groupBy("partner_id", "half")
    .agg(F.avg("monthly_revenue").alias("avg_revenue"))
    .groupBy("partner_id")
    .pivot("half", ["first", "second"])
    .agg(F.first("avg_revenue"))
    .withColumnRenamed("first", "first_half_avg")
    .withColumnRenamed("second", "second_half_avg")
)

halves = halves.withColumn(
    "pct_change",
    F.round(
        100.0 * (F.col("second_half_avg") - F.col("first_half_avg"))
        / F.col("first_half_avg"),
        1,
    ),
).withColumn(
    "health_segment",
    F.when(F.col("second_half_avg") < F.col("first_half_avg") * 0.9, "At Risk")
    .when(F.col("second_half_avg") > F.col("first_half_avg") * 1.1, "Growing")
    .otherwise("Stagnant"),
)

result = (
    halves.join(partners, on="partner_id")
    .select(
        "partner_id",
        "partner_name",
        "partner_type",
        F.round("first_half_avg", 2).alias("first_half_avg_monthly_revenue"),
        F.round("second_half_avg", 2).alias("second_half_avg_monthly_revenue"),
        "pct_change",
        "health_segment",
    )
    .orderBy("pct_change")
)

print("\n=== PARTNER HEALTH SEGMENTATION (PySpark) ===")
result.show(20, truncate=False)

print("\n=== SEGMENT COUNTS ===")
result.groupBy("health_segment").count().orderBy(F.desc("count")).show()

result.toPandas().to_csv("/content/pyspark_health_segmentation.csv", index=False)
print("\nSaved to /content/pyspark_health_segmentation.csv")

spark.stop()

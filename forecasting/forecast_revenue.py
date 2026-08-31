
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error
import matplotlib.pyplot as plt

DATA = "/content/affiliate-postgres-project/forecasting/monthly_revenue_by_partner.csv"
OUT_DIR = "/content/affiliate-postgres-project/forecasting"

FORECAST_MONTHS = 3
HOLDOUT_MONTHS = 3  


def moving_average_forecast(series, window=3, horizon=3):
    
    avg = series.tail(window).mean()
    return [avg] * horizon


def linear_regression_forecast(series, horizon=3):
    """Fit OLS trend line on the time index, extrapolate forward."""
    X = np.arange(len(series)).reshape(-1, 1)
    y = series.values
    model = LinearRegression().fit(X, y)
    future_X = np.arange(len(series), len(series) + horizon).reshape(-1, 1)
    preds = model.predict(future_X)
    return list(preds), model.coef_[0]


def backtest(series, method, window=3):
    """
    Hold out the last HOLDOUT_MONTHS, forecast them using only the
    months before, and compare to what actually happened.
    Returns MAE (mean absolute error) in Rand.
    """
    if len(series) < HOLDOUT_MONTHS + window + 1:
        return None  

    train = series.iloc[: -HOLDOUT_MONTHS]
    actual = series.iloc[-HOLDOUT_MONTHS:]

    if method == "moving_average":
        preds = moving_average_forecast(train, window=window, horizon=HOLDOUT_MONTHS)
    else:
        preds, _ = linear_regression_forecast(train, horizon=HOLDOUT_MONTHS)

    return mean_absolute_error(actual.values, preds)


def main():
    df = pd.read_csv(DATA, parse_dates=["month"])

   
    type_monthly = (
        df.groupby(["partner_type", "month"])["monthly_revenue"]
        .sum()
        .reset_index()
        .sort_values(["partner_type", "month"])
    )

    results = []
    backtest_results = []

    for ptype, grp in type_monthly.groupby("partner_type"):
        grp = grp.sort_values("month")
        series = grp.set_index("month")["monthly_revenue"]

        if len(series) < 4:
            continue 

        last_month = series.index.max()
        future_months = pd.date_range(
            last_month + pd.offsets.MonthBegin(1), periods=FORECAST_MONTHS, freq="MS"
        )

        ma_forecast = moving_average_forecast(series, window=3, horizon=FORECAST_MONTHS)
        lr_forecast, slope = linear_regression_forecast(series, horizon=FORECAST_MONTHS)

        for i, fm in enumerate(future_months):
            results.append(
                dict(
                    partner_type=ptype,
                    forecast_month=fm.date(),
                    moving_avg_forecast=round(ma_forecast[i], 2),
                    linear_regression_forecast=round(lr_forecast[i], 2),
                    monthly_trend_slope=round(slope, 2),
                )
            )

        ma_mae = backtest(series, "moving_average")
        lr_mae = backtest(series, "linear_regression")
        backtest_results.append(
            dict(
                partner_type=ptype,
                n_months_history=len(series),
                moving_avg_mae=round(ma_mae, 2) if ma_mae is not None else None,
                linear_regression_mae=round(lr_mae, 2) if lr_mae is not None else None,
                better_method=(
                    "moving_average"
                    if (ma_mae is not None and lr_mae is not None and ma_mae < lr_mae)
                    else "linear_regression"
                    if (ma_mae is not None and lr_mae is not None)
                    else "insufficient history to backtest"
                ),
            )
        )

    forecast_df = pd.DataFrame(results)
    backtest_df = pd.DataFrame(backtest_results)

    forecast_df.to_csv(f"{OUT_DIR}/forecast_by_partner_type.csv", index=False)
    backtest_df.to_csv(f"{OUT_DIR}/forecast_backtest_accuracy.csv", index=False)

    print("=== FORECAST (next 3 months, by partner type) ===")
    print(forecast_df.to_string(index=False))
    print("\n=== BACKTEST ACCURACY (lower MAE = better) ===")
    print(backtest_df.to_string(index=False))

    top_type = type_monthly.groupby("partner_type")["monthly_revenue"].sum().idxmax()
    grp = type_monthly[type_monthly.partner_type == top_type].sort_values("month")
    series = grp.set_index("month")["monthly_revenue"]

    ma_fc = moving_average_forecast(series, window=3, horizon=FORECAST_MONTHS)
    lr_fc, _ = linear_regression_forecast(series, horizon=FORECAST_MONTHS)
    future_months = pd.date_range(
        series.index.max() + pd.offsets.MonthBegin(1), periods=FORECAST_MONTHS, freq="MS"
    )

    plt.figure(figsize=(10, 5))
    plt.plot(series.index, series.values, marker="o", label="Actual", color="#2c3e50")
    plt.plot(future_months, ma_fc, marker="s", linestyle="--", label="Moving Avg Forecast", color="#3498db")
    plt.plot(future_months, lr_fc, marker="^", linestyle="--", label="Linear Regression Forecast", color="#e67e22")
    plt.axvline(series.index.max(), color="gray", linestyle=":", linewidth=1)
    plt.title(f"Monthly Revenue Forecast — {top_type} Partners")
    plt.ylabel("Revenue (ZAR)")
    plt.legend()
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/forecast_chart_{top_type.replace('/', '_')}.png", dpi=150)
    print(f"\nChart saved for top partner type: {top_type}")


if __name__ == "__main__":
    main()

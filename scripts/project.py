"""Project config shared by run_pipeline.py, build_databricks.py (and the Databricks deploy)."""
REPO = "da-learn-06-airline-delays"
NN = "06"
DASH_TITLE = "US airline delays and cancellations - 2015"
DASH_NAME = "da-learn-06 Airline delays"
NOTEBOOK = "airline_delays_pipeline_notebook"
DASH_FILE = "airline_delays_dashboard"
CURRENCY = "USD"
DATASET = "2015 Flight Delays and Cancellations (US DOT / BTS on-time performance, Kaggle usdot/flight-delays): flights, airlines, airports, cancellation codes"
RAW = {"stg_flights": {"file": "flights.parquet", "format": "parquet"},
       "stg_airlines": {"file": "airlines.parquet", "format": "parquet"},
       "stg_airports": {"file": "airports.parquet", "format": "parquet"},
       "stg_cancellation_codes": {"file": "cancellation_codes.parquet", "format": "parquet"}}
RAW_FILES = [v["file"] for v in RAW.values()]
# sample mode: same columns as CSV (text-only git push cannot carry Parquet)
SAMPLE_FILES = {"flights.parquet": "flights_sample.csv", "airlines.parquet": "airlines.csv",
                "airports.parquet": "airports.csv", "cancellation_codes.parquet": "cancellation_codes.csv"}
CLEAN = ["cln_airlines", "cln_airports", "cln_cancellation_codes", "cln_flights_flagged", "cln_flights"]
STAR = ["fact_flights", "dim_date", "dim_airline", "dim_airport", "dim_cancellation"]
PBI_CAP = {"fact_flights": 2000}
PBI_SAMPLE_FILTER = {"fact_flights": "date_key = 20150115"}
COMPARE_TABLES = ["a_monthly", "a_airline", "a_delay_causes", "a_cancellation_reasons", "a_hourly", "a_day_of_week", "a_distance_bands", "dq_issues"]
SHOT_CONFIG = {"engine": "duckdb (local, full data) + Databricks serverless SQL", "sql_dialect": "Spark/Databricks SQL + DuckDB shims (sql/00)",
               "period": "calendar year 2015 (US domestic, 14 reporting carriers)",
               "on_time": "arrival delay < 15 min, over completed (not cancelled, not diverted) flights",
               "delay_causes": "BTS cause minutes, reported only for flights arriving >= 15 min late",
               "airport_quirk": "October 2015 rows use numeric BTS airport ids; kept as UNK and excluded from airport/route views",
               "sample_rule": "data/raw = first flight of each carrier on 2015-01-15 + edge cases (each cancellation code, diverted, same-flight-number two-leg pair, Oct numeric airport, 2400 time, delay outlier), as CSV; full lookups"}
SHOT_QUERIES = {
    "airlines_best_otp": "SELECT airline_name, flights, on_time_pct FROM a_airline ORDER BY on_time_pct DESC LIMIT 3",
    "airlines_worst_otp": "SELECT airline_name, flights, on_time_pct FROM a_airline ORDER BY on_time_pct LIMIT 3",
    "delay_causes": "SELECT cause, share_pct FROM a_delay_causes ORDER BY minutes DESC",
    "worst_months": "SELECT month_label, on_time_pct, cancelled_pct FROM a_monthly ORDER BY on_time_pct LIMIT 3",
    "cancellation_reasons": "SELECT cancellation_reason, share_pct FROM a_cancellation_reasons ORDER BY cancelled_flights DESC",
}
METRIC_QUERIES = {
    "monthly": "SELECT * FROM a_monthly ORDER BY month",
    "airline": "SELECT * FROM a_airline ORDER BY flights DESC",
    "delay_causes": "SELECT * FROM a_delay_causes ORDER BY minutes DESC",
    "cancellation_reasons": "SELECT * FROM a_cancellation_reasons ORDER BY cancelled_flights DESC",
    "hourly": "SELECT * FROM a_hourly ORDER BY sched_dep_hour",
    "day_of_week": "SELECT * FROM a_day_of_week ORDER BY day_of_week",
    "distance_bands": "SELECT * FROM a_distance_bands ORDER BY distance_band",
    "top15_origin_airports": "SELECT * FROM a_origin_airports ORDER BY departures DESC LIMIT 15",
    "top10_routes": "SELECT * FROM a_routes ORDER BY flights DESC LIMIT 10",
    "worst_cancellation_days": "SELECT * FROM a_daily ORDER BY cancelled_pct DESC LIMIT 5",
}
CARDS = [("flights", "Flights", "{:,}"), ("avg_flights_per_day", "Flights / day", "{:,.0f}"), ("on_time_pct", "On-time arrivals", "{:.1f}%"),
         ("cancelled_pct", "Cancelled", "{:.2f}%"), ("diverted_pct", "Diverted", "{:.2f}%"),
         ("avg_arr_delay_min", "Avg arrival delay (min)", "{:.1f}"), ("avg_delay_when_late_min", "Avg delay when late (min)", "{:.1f}")]
DASH_KPI_SQL = "SELECT flights, on_time_pct / 100 AS on_time_rate, cancelled_pct / 100 AS cancelled_rate FROM {S}a_kpi_headline"
COUNTERS = [("flights", "Flights (2015)", "num"), ("on_time_rate", "On-time arrival rate", "pct")]
DASH_NOTE = "Source: US DOT / BTS 2015 on-time performance (Kaggle usdot/flight-delays, CC0). On-time = arrived < 15 min late. Tables: workspace.da_learn_06."
VIZ = [
    {"name": "otp_by_month", "title": "On-time arrival % by month", "kind": "line", "x": "month_label", "y": "on_time_pct", "fmt": "{:.1f}%",
     "sql": "SELECT month_label, on_time_pct FROM {S}a_monthly ORDER BY month"},
    {"name": "cancel_by_month", "title": "Cancellation rate by month (%)", "kind": "bar", "x": "month_label", "y": "cancelled_pct", "fmt": "{:.2f}%",
     "sql": "SELECT month_label, cancelled_pct FROM {S}a_monthly ORDER BY month"},
    {"name": "airline_otp", "title": "On-time arrival % by airline", "kind": "hbar", "x": "airline_name", "y": "on_time_pct", "fmt": "{:.1f}%",
     "sql": "SELECT airline_name, on_time_pct FROM {S}a_airline ORDER BY on_time_pct DESC"},
    {"name": "delay_causes", "title": "Share of late-arrival minutes by cause", "kind": "hbar", "x": "cause", "y": "share_pct", "fmt": "{:.1f}%",
     "sql": "SELECT cause, share_pct FROM {S}a_delay_causes ORDER BY share_pct DESC"},
    {"name": "hourly_dep_delay", "title": "Avg departure delay by scheduled hour (min)", "kind": "bar", "x": "sched_dep_hour", "y": "avg_dep_delay_min", "fmt": "{:.1f}",
     "sql": "SELECT sched_dep_hour, avg_dep_delay_min FROM {S}a_hourly ORDER BY sched_dep_hour"},
    {"name": "busiest_airports_delay", "title": "Avg departure delay, 10 busiest origins (min)", "kind": "hbar", "x": "origin_code", "y": "avg_dep_delay_min", "fmt": "{:.1f}",
     "sql": "SELECT origin_code, avg_dep_delay_min FROM (SELECT origin_code, avg_dep_delay_min, departures FROM {S}a_origin_airports ORDER BY departures DESC LIMIT 10) t ORDER BY avg_dep_delay_min DESC"},
]

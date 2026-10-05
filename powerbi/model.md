# Power BI model (star schema)

| Table | Grain | Key | Notes |
|---|---|---|---|
| fact_flights | one scheduled flight leg (2015) | (none; natural key date_key + airline_code + flight_number + origin_code + sched_dep_hhmm) | origin_code, dest_code, sched_dep_hour, distance_mi, distance_band, flight_status, is_cancelled, is_diverted, cancellation_code, is_on_time, is_arr_delayed_15, dep/arr delay, taxi, air/elapsed/scheduled time, five cause-minute columns, dq_delay_outlier, dq_numeric_airport_code |
| dim_date | day | date_key | flight_date, year, month, month_label ("01 Jan"), quarter, day_of_month, day_of_week (1 = Mon, BTS convention), day_name, is_weekend |
| dim_airline | carrier | airline_code | airline_name (14 reporting carriers) |
| dim_airport | airport | airport_code | airport_name, city, state, country, latitude, longitude; plus an `UNK` member for the October 2015 rows that carry numeric BTS ids |
| dim_cancellation | cancellation code | cancellation_code | cancellation_reason (A carrier, B weather, C National Air System, D security, N not cancelled) |

Relationships (single direction, many-to-one, from fact to dimension):
- fact_flights[date_key] → dim_date[date_key]
- fact_flights[airline_code] → dim_airline[airline_code]
- fact_flights[origin_code] → dim_airport[airport_code] (**active**, "Origin")
- fact_flights[dest_code] → dim_airport[airport_code] (**inactive**; use USERELATIONSHIP in arrival measures, or import dim_airport a second time as "Destination")
- fact_flights[cancellation_code] → dim_cancellation[cancellation_code]

`powerbi/data/` is sample-sized: the first 2,000 flights of Thu 2015-01-15 (ordered by all columns), with every date, airline, airport and cancellation code. Run `python run_pipeline.py --source full` and point Power BI at `data/clean_full/star/` for the full 5,819,078-row fact table.

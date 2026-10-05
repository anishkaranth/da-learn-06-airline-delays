-- 04_analysis.sql  KPIs and business questions. On-time = arrived < 15 min late (BTS definition), measured
-- over completed (not cancelled, not diverted) flights. Delay-cause minutes exist only for flights >= 15 min late.

CREATE OR REPLACE TABLE a_kpi_headline AS
SELECT COUNT(*) AS flights,
  SUM(1 - is_cancelled - is_diverted) AS completed_flights,
  ROUND(COUNT(*) / COUNT(DISTINCT date_key), 0) AS avg_flights_per_day,
  ROUND(100.0 * SUM(is_on_time) / NULLIF(SUM(is_on_time + is_arr_delayed_15), 0), 2) AS on_time_pct,
  ROUND(100.0 * AVG(CAST(is_cancelled AS DOUBLE)), 2) AS cancelled_pct,
  ROUND(100.0 * AVG(CAST(is_diverted AS DOUBLE)), 2) AS diverted_pct,
  ROUND(AVG(CASE WHEN is_cancelled = 0 AND is_diverted = 0 THEN arr_delay_min END), 2) AS avg_arr_delay_min,
  ROUND(AVG(CASE WHEN is_cancelled = 0 THEN dep_delay_min END), 2) AS avg_dep_delay_min,
  ROUND(AVG(CASE WHEN is_arr_delayed_15 = 1 THEN arr_delay_min END), 2) AS avg_delay_when_late_min,
  SUM(CASE WHEN is_arr_delayed_15 = 1 THEN arr_delay_min ELSE 0 END) AS total_late_arrival_min,
  COUNT(DISTINCT airline_code) AS airlines,
  COUNT(DISTINCT CASE WHEN origin_code <> 'UNK' THEN origin_code END) AS origin_airports,
  ROUND(AVG(CAST(taxi_out_min AS DOUBLE)), 2) AS avg_taxi_out_min
FROM fact_flights;

-- Q1: seasonality
CREATE OR REPLACE TABLE a_monthly AS
SELECT d.month, d.month_label, COUNT(*) AS flights,
  ROUND(100.0 * SUM(f.is_on_time) / NULLIF(SUM(f.is_on_time + f.is_arr_delayed_15), 0), 2) AS on_time_pct,
  ROUND(100.0 * AVG(CAST(f.is_cancelled AS DOUBLE)), 2) AS cancelled_pct,
  ROUND(AVG(CASE WHEN f.is_cancelled = 0 AND f.is_diverted = 0 THEN f.arr_delay_min END), 2) AS avg_arr_delay_min
FROM fact_flights f JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.month, d.month_label;

CREATE OR REPLACE TABLE a_daily AS
SELECT d.flight_date, d.day_name, COUNT(*) AS flights, SUM(f.is_cancelled) AS cancelled,
  ROUND(100.0 * AVG(CAST(f.is_cancelled AS DOUBLE)), 2) AS cancelled_pct,
  ROUND(100.0 * SUM(f.is_on_time) / NULLIF(SUM(f.is_on_time + f.is_arr_delayed_15), 0), 2) AS on_time_pct
FROM fact_flights f JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.flight_date, d.day_name;

CREATE OR REPLACE TABLE a_day_of_week AS
SELECT d.day_of_week, d.day_name, COUNT(*) AS flights, COUNT(DISTINCT d.date_key) AS days,
  ROUND(COUNT(*) / COUNT(DISTINCT d.date_key), 0) AS avg_flights_per_day,
  ROUND(100.0 * SUM(f.is_on_time) / NULLIF(SUM(f.is_on_time + f.is_arr_delayed_15), 0), 2) AS on_time_pct
FROM fact_flights f JOIN dim_date d ON d.date_key = f.date_key
GROUP BY d.day_of_week, d.day_name;

-- Q2: which carriers are most / least reliable
CREATE OR REPLACE TABLE a_airline AS
SELECT a.airline_code, a.airline_name, COUNT(*) AS flights,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct,
  ROUND(100.0 * SUM(f.is_on_time) / NULLIF(SUM(f.is_on_time + f.is_arr_delayed_15), 0), 2) AS on_time_pct,
  ROUND(100.0 * AVG(CAST(f.is_cancelled AS DOUBLE)), 2) AS cancelled_pct,
  ROUND(AVG(CASE WHEN f.is_cancelled = 0 AND f.is_diverted = 0 THEN f.arr_delay_min END), 2) AS avg_arr_delay_min,
  ROUND(AVG(CASE WHEN f.is_arr_delayed_15 = 1 THEN f.arr_delay_min END), 2) AS avg_delay_when_late_min
FROM fact_flights f JOIN dim_airline a ON a.airline_code = f.airline_code
GROUP BY a.airline_code, a.airline_name;

-- Q3: what causes the delay minutes (BTS cause attribution, flights >= 15 min late)
CREATE OR REPLACE TABLE a_delay_causes AS
WITH s AS (
  SELECT 'Late-arriving aircraft' AS cause, SUM(late_aircraft_delay_min) AS minutes FROM fact_flights
  UNION ALL SELECT 'Airline / carrier', SUM(carrier_delay_min) FROM fact_flights
  UNION ALL SELECT 'National Air System', SUM(nas_delay_min) FROM fact_flights
  UNION ALL SELECT 'Weather', SUM(weather_delay_min) FROM fact_flights
  UNION ALL SELECT 'Security', SUM(security_delay_min) FROM fact_flights
)
SELECT cause, minutes, ROUND(100.0 * minutes / NULLIF(SUM(minutes) OVER (), 0), 2) AS share_pct FROM s;

CREATE OR REPLACE TABLE a_cancellation_reasons AS
SELECT c.cancellation_reason, COUNT(*) AS cancelled_flights,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM fact_flights f JOIN dim_cancellation c ON c.cancellation_code = f.cancellation_code
WHERE f.is_cancelled = 1
GROUP BY c.cancellation_reason;

-- Q4: time of day - delays build up through the day
CREATE OR REPLACE TABLE a_hourly AS
SELECT sched_dep_hour, COUNT(*) AS flights,
  ROUND(AVG(CASE WHEN is_cancelled = 0 THEN dep_delay_min END), 2) AS avg_dep_delay_min,
  ROUND(100.0 * SUM(is_on_time) / NULLIF(SUM(is_on_time + is_arr_delayed_15), 0), 2) AS on_time_pct
FROM fact_flights
GROUP BY sched_dep_hour;

-- Q5: airports (Oct 2015 rows without IATA codes excluded) - the 15 busiest origins
CREATE OR REPLACE TABLE a_origin_airports AS
SELECT f.origin_code, p.airport_name, p.city, p.state, COUNT(*) AS departures,
  ROUND(100.0 * SUM(f.is_on_time) / NULLIF(SUM(f.is_on_time + f.is_arr_delayed_15), 0), 2) AS on_time_pct,
  ROUND(AVG(CASE WHEN f.is_cancelled = 0 THEN f.dep_delay_min END), 2) AS avg_dep_delay_min,
  ROUND(100.0 * AVG(CAST(f.is_cancelled AS DOUBLE)), 2) AS cancelled_pct,
  ROUND(AVG(CAST(f.taxi_out_min AS DOUBLE)), 2) AS avg_taxi_out_min
FROM fact_flights f JOIN dim_airport p ON p.airport_code = f.origin_code
WHERE f.origin_code <> 'UNK'
GROUP BY f.origin_code, p.airport_name, p.city, p.state;

CREATE OR REPLACE TABLE a_routes AS
SELECT origin_code || '-' || dest_code AS route, COUNT(*) AS flights, ROUND(AVG(CAST(distance_mi AS DOUBLE)), 0) AS distance_mi,
  ROUND(100.0 * SUM(is_on_time) / NULLIF(SUM(is_on_time + is_arr_delayed_15), 0), 2) AS on_time_pct
FROM fact_flights
WHERE origin_code <> 'UNK' AND dest_code <> 'UNK'
GROUP BY origin_code, dest_code;

CREATE OR REPLACE TABLE a_distance_bands AS
SELECT distance_band, COUNT(*) AS flights,
  ROUND(100.0 * SUM(is_on_time) / NULLIF(SUM(is_on_time + is_arr_delayed_15), 0), 2) AS on_time_pct,
  ROUND(100.0 * AVG(CAST(is_cancelled AS DOUBLE)), 2) AS cancelled_pct,
  ROUND(AVG(CASE WHEN is_cancelled = 0 AND is_diverted = 0 THEN arr_delay_min END), 2) AS avg_arr_delay_min,
  ROUND(AVG(CASE WHEN is_cancelled = 0 AND is_diverted = 0 THEN dep_delay_min - arr_delay_min END), 2) AS avg_time_made_up_min
FROM fact_flights
GROUP BY distance_band;

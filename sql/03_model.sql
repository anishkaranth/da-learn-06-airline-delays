-- 03_model.sql  star schema: fact_flights + dim_date, dim_airline, dim_airport, dim_cancellation

CREATE OR REPLACE TABLE dim_airline AS
SELECT airline_code, airline_name FROM cln_airlines;

-- 'UNK' member catches the October 2015 rows whose airports arrive as numeric BTS ids
CREATE OR REPLACE TABLE dim_airport AS
SELECT iata_code AS airport_code, airport_name, city, state, country, latitude, longitude FROM cln_airports
UNION ALL
SELECT 'UNK', 'Unknown (Oct 2015 numeric BTS airport id)', NULL, NULL, NULL, NULL, NULL;

CREATE OR REPLACE TABLE dim_cancellation AS
SELECT cancellation_code, cancellation_reason FROM cln_cancellation_codes
UNION ALL SELECT 'N', 'Not cancelled';

CREATE OR REPLACE TABLE dim_date AS
SELECT DISTINCT date_key, flight_date, yr AS year, mo AS month,
  CASE mo WHEN 1 THEN '01 Jan' WHEN 2 THEN '02 Feb' WHEN 3 THEN '03 Mar' WHEN 4 THEN '04 Apr' WHEN 5 THEN '05 May' WHEN 6 THEN '06 Jun'
          WHEN 7 THEN '07 Jul' WHEN 8 THEN '08 Aug' WHEN 9 THEN '09 Sep' WHEN 10 THEN '10 Oct' WHEN 11 THEN '11 Nov' ELSE '12 Dec' END AS month_label,
  CAST(FLOOR((mo - 1) / 3) AS INT) + 1 AS quarter, dy AS day_of_month,
  bts_dow AS day_of_week,
  CASE bts_dow WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue' WHEN 3 THEN 'Wed' WHEN 4 THEN 'Thu' WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat' ELSE 'Sun' END AS day_name,
  CASE WHEN bts_dow IN (6, 7) THEN 1 ELSE 0 END AS is_weekend
FROM cln_flights;

CREATE OR REPLACE TABLE fact_flights AS
SELECT date_key, airline_code, flight_number, tail_number,
  COALESCE(origin_iata, 'UNK') AS origin_code, COALESCE(dest_iata, 'UNK') AS dest_code,
  sched_dep_hhmm, sched_dep_hour, distance_mi,
  CASE WHEN distance_mi < 500 THEN '1 <500 mi' WHEN distance_mi < 1000 THEN '2 500-999 mi' WHEN distance_mi < 1500 THEN '3 1000-1499 mi'
       WHEN distance_mi < 2500 THEN '4 1500-2499 mi' ELSE '5 2500+ mi' END AS distance_band,
  flight_status, is_cancelled, is_diverted, COALESCE(cancellation_code, 'N') AS cancellation_code,
  is_on_time, is_arr_delayed_15, dep_delay_min, arr_delay_min, taxi_out_min, taxi_in_min, air_time_min, elapsed_time_min, scheduled_time_min,
  nas_delay_min, security_delay_min, carrier_delay_min, late_aircraft_delay_min, weather_delay_min,
  dq_delay_outlier, dq_numeric_airport_code
FROM cln_flights;

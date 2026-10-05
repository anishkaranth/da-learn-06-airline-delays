-- 02_cleaning.sql  types, trimming, standardisation, dates, dedupe, outlier and integrity flags.
-- Every CAST is a TRY_CAST so the same script runs on DuckDB and on ANSI-mode Databricks SQL.

-- Carriers: trim codes/names, one row per IATA code
CREATE OR REPLACE TABLE cln_airlines AS
SELECT UPPER(TRIM(CAST(IATA_CODE AS STRING))) AS airline_code, TRIM(CAST(AIRLINE AS STRING)) AS airline_name
FROM stg_airlines
WHERE IATA_CODE IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(CAST(IATA_CODE AS STRING))) ORDER BY TRIM(CAST(AIRLINE AS STRING))) = 1;

-- Airports: trim, typed coordinates, flag the 3 airports that ship without lat/long
CREATE OR REPLACE TABLE cln_airports AS
SELECT UPPER(TRIM(CAST(IATA_CODE AS STRING))) AS iata_code, TRIM(CAST(AIRPORT AS STRING)) AS airport_name,
  TRIM(CAST(CITY AS STRING)) AS city, UPPER(TRIM(CAST(STATE AS STRING))) AS state, TRIM(CAST(COUNTRY AS STRING)) AS country,
  TRY_CAST(LATITUDE AS DOUBLE) AS latitude, TRY_CAST(LONGITUDE AS DOUBLE) AS longitude,
  CASE WHEN TRY_CAST(LATITUDE AS DOUBLE) IS NULL OR TRY_CAST(LONGITUDE AS DOUBLE) IS NULL THEN 1 ELSE 0 END AS dq_missing_coords
FROM stg_airports
WHERE IATA_CODE IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(CAST(IATA_CODE AS STRING))) ORDER BY TRIM(CAST(AIRPORT AS STRING))) = 1;

CREATE OR REPLACE TABLE cln_cancellation_codes AS
SELECT UPPER(TRIM(CAST(CANCELLATION_REASON AS STRING))) AS cancellation_code, TRIM(CAST(CANCELLATION_DESCRIPTION AS STRING)) AS cancellation_reason
FROM stg_cancellation_codes WHERE CANCELLATION_REASON IS NOT NULL;

-- Flights: typed + derived columns and one 0/1 flag per data-quality rule
CREATE OR REPLACE TABLE cln_flights_flagged AS
WITH t AS (
  SELECT
    TRY_CAST(YEAR AS INT) AS yr, TRY_CAST(MONTH AS INT) AS mo, TRY_CAST(DAY AS INT) AS dy, TRY_CAST(DAY_OF_WEEK AS INT) AS bts_dow,
    UPPER(TRIM(CAST(AIRLINE AS STRING))) AS airline_code, TRY_CAST(FLIGHT_NUMBER AS INT) AS flight_number,
    NULLIF(UPPER(TRIM(CAST(TAIL_NUMBER AS STRING))), '') AS tail_number,
    UPPER(TRIM(CAST(ORIGIN_AIRPORT AS STRING))) AS origin_raw, UPPER(TRIM(CAST(DESTINATION_AIRPORT AS STRING))) AS dest_raw,
    TRY_CAST(SCHEDULED_DEPARTURE AS INT) AS sched_dep_hhmm, TRY_CAST(DEPARTURE_TIME AS INT) AS dep_hhmm,
    TRY_CAST(SCHEDULED_ARRIVAL AS INT) AS sched_arr_hhmm, TRY_CAST(ARRIVAL_TIME AS INT) AS arr_hhmm,
    TRY_CAST(DEPARTURE_DELAY AS INT) AS dep_delay_min, TRY_CAST(ARRIVAL_DELAY AS INT) AS arr_delay_min,
    TRY_CAST(TAXI_OUT AS INT) AS taxi_out_min, TRY_CAST(TAXI_IN AS INT) AS taxi_in_min,
    TRY_CAST(SCHEDULED_TIME AS INT) AS scheduled_time_min, TRY_CAST(ELAPSED_TIME AS INT) AS elapsed_time_min,
    TRY_CAST(AIR_TIME AS INT) AS air_time_min, TRY_CAST(DISTANCE AS INT) AS distance_mi,
    COALESCE(TRY_CAST(DIVERTED AS INT), 0) AS is_diverted, COALESCE(TRY_CAST(CANCELLED AS INT), 0) AS is_cancelled,
    NULLIF(UPPER(TRIM(CAST(CANCELLATION_REASON AS STRING))), '') AS cancellation_code,
    TRY_CAST(AIR_SYSTEM_DELAY AS INT) AS nas_delay_min, TRY_CAST(SECURITY_DELAY AS INT) AS security_delay_min,
    TRY_CAST(AIRLINE_DELAY AS INT) AS carrier_delay_min, TRY_CAST(LATE_AIRCRAFT_DELAY AS INT) AS late_aircraft_delay_min,
    TRY_CAST(WEATHER_DELAY AS INT) AS weather_delay_min
  FROM stg_flights
), d AS (
  SELECT t.*, make_date(yr, mo, dy) AS flight_date, yr * 10000 + mo * 100 + dy AS date_key,
    -- BTS hhmm: 2400 means midnight; hour 24 folds to 0
    CAST(FLOOR(sched_dep_hhmm / 100) AS INT) % 24 AS sched_dep_hour,
    -- October 2015 rows carry 5-digit BTS AirportSeqIDs instead of IATA codes (known quirk of this dataset)
    CASE WHEN TRY_CAST(origin_raw AS INT) IS NULL THEN origin_raw END AS origin_iata,
    CASE WHEN TRY_CAST(dest_raw AS INT) IS NULL THEN dest_raw END AS dest_iata,
    ROW_NUMBER() OVER (PARTITION BY yr, mo, dy, airline_code, flight_number, origin_raw, dest_raw, sched_dep_hhmm ORDER BY tail_number, dep_hhmm, arr_hhmm, sched_arr_hhmm, distance_mi) AS dup_rank
  FROM t
)
SELECT d.*,
  CASE WHEN is_cancelled = 1 THEN 'Cancelled' WHEN is_diverted = 1 THEN 'Diverted' ELSE 'Completed' END AS flight_status,
  CASE WHEN is_cancelled = 0 AND is_diverted = 0 AND arr_delay_min >= 15 THEN 1 ELSE 0 END AS is_arr_delayed_15,
  CASE WHEN is_cancelled = 0 AND is_diverted = 0 AND arr_delay_min < 15 THEN 1 ELSE 0 END AS is_on_time,
  CASE WHEN dup_rank > 1 THEN 1 ELSE 0 END AS dq_duplicate,
  CASE WHEN flight_date IS NULL OR yr <> 2015 THEN 1 ELSE 0 END AS dq_bad_date,
  CASE WHEN airline_code NOT IN (SELECT airline_code FROM cln_airlines) THEN 1 ELSE 0 END AS dq_unknown_airline,
  CASE WHEN origin_iata IS NULL OR dest_iata IS NULL THEN 1 ELSE 0 END AS dq_numeric_airport_code,
  CASE WHEN (origin_iata IS NOT NULL AND origin_iata NOT IN (SELECT iata_code FROM cln_airports))
         OR (dest_iata IS NOT NULL AND dest_iata NOT IN (SELECT iata_code FROM cln_airports)) THEN 1 ELSE 0 END AS dq_unknown_airport,
  CASE WHEN distance_mi IS NULL OR distance_mi <= 0 THEN 1 ELSE 0 END AS dq_bad_distance,
  CASE WHEN is_cancelled = 0 AND is_diverted = 0 AND arr_delay_min IS NULL THEN 1 ELSE 0 END AS dq_missing_arr_delay,
  CASE WHEN is_cancelled = 1 AND cancellation_code IS NULL THEN 1 ELSE 0 END AS dq_cancel_no_reason,
  CASE WHEN ABS(COALESCE(arr_delay_min, 0)) > 600 OR ABS(COALESCE(dep_delay_min, 0)) > 600 THEN 1 ELSE 0 END AS dq_delay_outlier,
  CASE WHEN nas_delay_min IS NOT NULL
        AND nas_delay_min + security_delay_min + carrier_delay_min + late_aircraft_delay_min + weather_delay_min <> arr_delay_min THEN 1 ELSE 0 END AS dq_cause_mismatch,
  CASE WHEN bts_dow <> ((dayofweek(make_date(yr, mo, dy)) + 5) % 7) + 1 THEN 1 ELSE 0 END AS dq_dow_mismatch
FROM d;

-- Clean flights: drop duplicate flight keys (date, carrier, flight no, origin, destination, sched dep), bad dates and unknown carriers. Outliers and the
-- October airport-code quirk are KEPT and flagged (they are real flights).
CREATE OR REPLACE TABLE cln_flights AS
SELECT * FROM cln_flights_flagged
WHERE dq_duplicate = 0 AND dq_bad_date = 0 AND dq_unknown_airline = 0;

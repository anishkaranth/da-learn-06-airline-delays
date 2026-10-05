-- 05_quality_checks.sql  before/after counts, DQ issue counts and hard assertions

CREATE OR REPLACE TABLE dq_row_counts AS
SELECT 'flights' AS entity, (SELECT COUNT(*) FROM stg_flights) AS raw_rows, (SELECT COUNT(*) FROM cln_flights) AS clean_rows,
       (SELECT COUNT(*) FROM stg_flights) - (SELECT COUNT(*) FROM cln_flights) AS removed_rows, 'flight leg' AS grain
UNION ALL SELECT 'airlines', (SELECT COUNT(*) FROM stg_airlines), (SELECT COUNT(*) FROM cln_airlines), (SELECT COUNT(*) FROM stg_airlines) - (SELECT COUNT(*) FROM cln_airlines), 'carrier'
UNION ALL SELECT 'airports', (SELECT COUNT(*) FROM stg_airports), (SELECT COUNT(*) FROM cln_airports), (SELECT COUNT(*) FROM stg_airports) - (SELECT COUNT(*) FROM cln_airports), 'airport'
UNION ALL SELECT 'fact_flights', NULL, (SELECT COUNT(*) FROM fact_flights), NULL, 'flight leg'
UNION ALL SELECT 'dim_date', NULL, (SELECT COUNT(*) FROM dim_date), NULL, 'day'
UNION ALL SELECT 'dim_airline', NULL, (SELECT COUNT(*) FROM dim_airline), NULL, 'carrier'
UNION ALL SELECT 'dim_airport', NULL, (SELECT COUNT(*) FROM dim_airport), NULL, 'airport (+UNK)'
UNION ALL SELECT 'dim_cancellation', NULL, (SELECT COUNT(*) FROM dim_cancellation), NULL, 'cancellation code (+N)';

-- flags overlap, so each count is "rows with this flag"
CREATE OR REPLACE TABLE dq_issues AS
SELECT 'duplicate flight key (date, carrier, flight no, origin, dest, sched dep) - removed' AS check_name, (SELECT SUM(dq_duplicate) FROM cln_flights_flagged) AS affected_rows
UNION ALL SELECT 'invalid / non-2015 date - removed', (SELECT SUM(dq_bad_date) FROM cln_flights_flagged)
UNION ALL SELECT 'carrier not in airlines lookup - removed', (SELECT SUM(dq_unknown_airline) FROM cln_flights_flagged)
UNION ALL SELECT 'numeric BTS airport id instead of IATA (Oct 2015) - kept as UNK', (SELECT SUM(dq_numeric_airport_code) FROM cln_flights_flagged)
UNION ALL SELECT 'IATA airport not in airports lookup', (SELECT SUM(dq_unknown_airport) FROM cln_flights_flagged)
UNION ALL SELECT 'distance missing or <= 0', (SELECT SUM(dq_bad_distance) FROM cln_flights_flagged)
UNION ALL SELECT 'completed flight without arrival delay', (SELECT SUM(dq_missing_arr_delay) FROM cln_flights_flagged)
UNION ALL SELECT 'cancelled without reason code', (SELECT SUM(dq_cancel_no_reason) FROM cln_flights_flagged)
UNION ALL SELECT 'delay > 10 h (outlier, kept and flagged)', (SELECT SUM(dq_delay_outlier) FROM cln_flights_flagged)
UNION ALL SELECT 'cause minutes do not sum to arrival delay', (SELECT SUM(dq_cause_mismatch) FROM cln_flights_flagged)
UNION ALL SELECT 'BTS day_of_week disagrees with date', (SELECT SUM(dq_dow_mismatch) FROM cln_flights_flagged)
UNION ALL SELECT 'same flight no + origin + sched dep, different destination (multi-leg; kept)', (SELECT COUNT(*) FROM (SELECT yr, mo, dy, airline_code, flight_number, origin_raw, sched_dep_hhmm FROM cln_flights_flagged
      GROUP BY yr, mo, dy, airline_code, flight_number, origin_raw, sched_dep_hhmm HAVING COUNT(*) > 1) x)
UNION ALL SELECT 'tail number missing (kept)', (SELECT COUNT(*) FROM cln_flights_flagged WHERE tail_number IS NULL)
UNION ALL SELECT 'airports without coordinates (kept)', (SELECT SUM(dq_missing_coords) FROM cln_airports)
UNION ALL SELECT 'total flight rows removed', (SELECT COUNT(*) FROM stg_flights) - (SELECT COUNT(*) FROM cln_flights);

CREATE OR REPLACE TABLE dq_assertions AS
WITH c AS (
  SELECT 'every clean flight is in fact_flights' AS check_name, (SELECT COUNT(*) FROM cln_flights) - (SELECT COUNT(*) FROM fact_flights) AS failed_rows
  UNION ALL SELECT 'flight key unique in fact', (SELECT COUNT(*) FROM (SELECT date_key, airline_code, flight_number, origin_code, dest_code, sched_dep_hhmm, COUNT(*) AS n
      FROM fact_flights WHERE origin_code <> 'UNK' GROUP BY date_key, airline_code, flight_number, origin_code, dest_code, sched_dep_hhmm HAVING COUNT(*) > 1) x)
  UNION ALL SELECT 'airline exists in dim_airline', (SELECT COUNT(*) FROM fact_flights f LEFT JOIN dim_airline a ON a.airline_code = f.airline_code WHERE a.airline_code IS NULL)
  UNION ALL SELECT 'origin exists in dim_airport', (SELECT COUNT(*) FROM fact_flights f LEFT JOIN dim_airport a ON a.airport_code = f.origin_code WHERE a.airport_code IS NULL)
  UNION ALL SELECT 'destination exists in dim_airport', (SELECT COUNT(*) FROM fact_flights f LEFT JOIN dim_airport a ON a.airport_code = f.dest_code WHERE a.airport_code IS NULL)
  UNION ALL SELECT 'date exists in dim_date', (SELECT COUNT(*) FROM fact_flights f LEFT JOIN dim_date d ON d.date_key = f.date_key WHERE d.date_key IS NULL)
  UNION ALL SELECT 'cancellation code exists in dim_cancellation', (SELECT COUNT(*) FROM fact_flights f LEFT JOIN dim_cancellation c ON c.cancellation_code = f.cancellation_code WHERE c.cancellation_code IS NULL)
  UNION ALL SELECT 'every cancelled flight has a reason', (SELECT COUNT(*) FROM fact_flights WHERE is_cancelled = 1 AND cancellation_code = 'N')
  UNION ALL SELECT 'status flags exclusive (cancelled + diverted <= 1)', (SELECT COUNT(*) FROM fact_flights WHERE is_cancelled + is_diverted > 1)
  UNION ALL SELECT 'on-time + late = completed flights', (SELECT ABS(SUM(is_on_time + is_arr_delayed_15) - SUM(1 - is_cancelled - is_diverted)) FROM fact_flights)
  UNION ALL SELECT 'monthly flights sum = fact rows', (SELECT ABS((SELECT SUM(flights) FROM a_monthly) - (SELECT COUNT(*) FROM fact_flights)))
  UNION ALL SELECT 'airline flights sum = fact rows', (SELECT ABS((SELECT SUM(flights) FROM a_airline) - (SELECT COUNT(*) FROM fact_flights)))
  UNION ALL SELECT 'positive distance', (SELECT COUNT(*) FROM fact_flights WHERE distance_mi <= 0)
  UNION ALL SELECT 'airport codes unique in dim_airport', (SELECT COUNT(*) - COUNT(DISTINCT airport_code) FROM dim_airport)
)
SELECT check_name, failed_rows, CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status FROM c;

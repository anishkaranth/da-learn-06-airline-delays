-- 01_staging.sql  Land the four BTS/Kaggle flight-delay files as-is. {{RAW_DIR}} is set by run_pipeline.py.
-- Full run reads the Parquet mirror; the committed sample holds the same columns as CSV (run_pipeline swaps the names).
-- Databricks: read_files('<volume>/flights.parquet', format => 'parquet') etc. (see databricks/ notebook)
CREATE OR REPLACE TABLE stg_flights AS
SELECT * FROM '{{RAW_DIR}}/flights.parquet';

CREATE OR REPLACE TABLE stg_airlines AS
SELECT * FROM '{{RAW_DIR}}/airlines.parquet';

CREATE OR REPLACE TABLE stg_airports AS
SELECT * FROM '{{RAW_DIR}}/airports.parquet';

CREATE OR REPLACE TABLE stg_cancellation_codes AS
SELECT * FROM '{{RAW_DIR}}/cancellation_codes.parquet';

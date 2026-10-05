#!/usr/bin/env python3
"""Build the git-sized raw sample in data/raw/ from data/raw_full/ (deterministic).

Rule: the first scheduled departure of every carrier on Thu 2015-01-15 (14 flights) plus the first row of each edge case
the cleaning handles: each cancellation code (A/B/C/D), a diversion, the one flight number departing the same airport at the same time to two destinations (both rows), an October
row with numeric BTS airport ids, a 2400 (midnight) departure time and the largest arrival delay. Written as CSV with the
original column names. The three lookups are tiny, so they are committed in full (as CSV)."""
import pathlib
import duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL, OUT = ROOT / "data/raw_full", ROOT / "data/raw"
OUT.mkdir(parents=True, exist_ok=True)
con = duckdb.connect()
con.execute(f"CREATE TABLE t AS SELECT * FROM '{FULL}/flights.parquet'")
order = "MONTH, DAY, SCHEDULED_DEPARTURE, AIRLINE, FLIGHT_NUMBER, ORIGIN_AIRPORT, TAIL_NUMBER"
key = "YEAR, MONTH, DAY, AIRLINE, FLIGHT_NUMBER, ORIGIN_AIRPORT, SCHEDULED_DEPARTURE"
rules = [f"CANCELLATION_REASON = '{c}'" for c in "ABCD"] + [
    "DIVERTED = 1", "MONTH = 10 AND length(ORIGIN_AIRPORT) = 5", "DEPARTURE_TIME = '2400'",
    "ARRIVAL_DELAY = (SELECT MAX(ARRIVAL_DELAY) FROM t)"]
parts = ["(SELECT * FROM t WHERE MONTH = 1 AND DAY = 15 QUALIFY ROW_NUMBER() OVER (PARTITION BY AIRLINE ORDER BY SCHEDULED_DEPARTURE, FLIGHT_NUMBER) = 1)"]
parts += [f"(SELECT * FROM t WHERE {r} ORDER BY {order} LIMIT 1)" for r in rules]
parts.append(f"(SELECT * FROM t QUALIFY COUNT(*) OVER (PARTITION BY {key}) > 1)")
con.execute("CREATE TABLE s AS " + " UNION ALL ".join(parts))
con.execute(f"COPY (SELECT * FROM s ORDER BY {order}) TO '{OUT}/flights_sample.csv' (HEADER)")
for f in ["airlines", "airports", "cancellation_codes"]:
    con.execute(f"COPY (SELECT * FROM '{FULL}/{f}.parquet') TO '{OUT}/{f}.csv' (HEADER)")
print(con.sql("SELECT COUNT(*) FROM s").fetchone()[0], "sample flights")

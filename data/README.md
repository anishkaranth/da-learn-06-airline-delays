# data/

- `raw/flights_sample.csv` is a 24-row sample of the real 2015 flights file, built by `scripts/make_sample.py`. It holds the first scheduled departure of each of the 14 carriers on Thu 2015-01-15, plus the first real row of each edge case the cleaning handles: one cancellation for each reason code (A carrier, B weather, C National Air System, D security), a diversion, the one flight number that left the same airport at the same time for two destinations (AA 803 from STT on 2015-08-29 to CLT and SJU, both cancelled; kept as two legs), an October row whose airports are numeric BTS ids (`14747`), a departure time of `2400` and the year's largest arrival delay (1,971 min). Columns and names match the source file.
- `raw/airlines.csv` (14 carriers), `raw/airports.csv` (322 airports) and `raw/cancellation_codes.csv` (4 codes) are the complete lookup tables, converted from Parquet to CSV unchanged.
- `raw_full/` (git-ignored) holds the full year, fetched by `python scripts/download_full_data.py` (~144 MB, SHA-256 verified).
- `clean_full/` (git-ignored) holds the full star-schema CSV exports written by the runner.

Source: US DOT Bureau of Transportation Statistics on-time performance data, as published on Kaggle (https://www.kaggle.com/datasets/usdot/flight-delays, CC0 Public Domain) and mirrored as Parquet at https://huggingface.co/datasets/hsanchezp/us-dot-flight-delays-2015. Column definitions: https://www.transtats.bts.gov/Fields.asp?gnoyr_VQ=FGJ

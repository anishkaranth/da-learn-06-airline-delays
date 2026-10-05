# Build guide (Power BI Desktop)

1. **Get data → Text/CSV:** load the five files in `powerbi/data/`, or `data/clean_full/star/` after a full run. Set date_key, flight_number, delay/time/distance columns and the 0/1 flags to *Whole number*, flight_date to *Date*, latitude/longitude to *Decimal number* and every code column to *Text*.
2. **Model view:** create the relationships in `model.md`. Mark dim_date as a date table on flight_date. Leave the destination → dim_airport relationship inactive.
3. **Sort columns:** sort dim_date[month_label] by dim_date[month] and dim_date[day_name] by dim_date[day_of_week]. The distance_band text already starts with a sort digit.
4. **Measures:** create a blank *_Measures* table and paste each line of `measures.dax` as a new measure. Format the % measures as percentages with 2 decimals and the minute measures with 1 decimal.
5. **Visuals:** follow `dashboard_spec.md`. For the cause chart, either drop the five share measures into one clustered bar, or unpivot the five cause-minute columns in Power Query.
6. **Validate:** on full data the cards must equal `results/metrics.json` (5,819,078 flights; 81.39% on time; 1.54% cancelled). On the sample, expect 2,000 flights, all on 2015-01-15.

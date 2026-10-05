# Power BI dashboard spec: "US Airline Delays 2015"

**Page 1 Overview** (full-data targets to check against `results/metrics.json`)
- KPI cards: Flights (5,819,078), Flights per Day (15,943), On-time Rate % (81.39%), Cancellation Rate % (1.54%), Diversion Rate % (0.26%), Avg Delay When Late (58.9 min)
- Line chart: On-time Rate % by dim_date[month_label] (low 76.52% in Jun, high 87.56% in Oct)
- Column chart: Cancellation Rate % by dim_date[month_label] (Feb peaks at 4.78%)
- Column chart: Avg Departure Delay by fact_flights[sched_dep_hour] (1.9 min at 05:00 rising to 15.2 min at 20:00)

**Page 2 Carriers and causes**
- Bar chart: On-time Rate % by dim_airline[airline_name] (Hawaiian 88.67% best, Spirit 70.29% worst)
- Bar chart: Late Aircraft / Carrier / NAS / Weather / Security share of cause minutes (39.84% / 32.20% / 22.88% / 4.95% / 0.13%)
- Donut: Cancelled Flights by dim_cancellation[cancellation_reason] (Weather 54.35%)
- Table: top origins by Flights with On-time Rate %, Avg Departure Delay and Avg Taxi Out (filter origin_code <> "UNK")

**Slicers:** dim_date[month_label], dim_airline[airline_name], dim_airport[state], fact_flights[distance_band]

**Theme:** a single teal accent (#1f6f8b) to match `results/charts/dashboard.svg`.

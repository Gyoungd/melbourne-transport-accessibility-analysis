# Q1 Analysis Summary

## Q1 Business Question
**How equitably is public transport service supplied across Melbourne Suburbs (SA2) during weekdays?**

This analysis evaluates weekday public transport accessibility from a **pessenger-centric perspective**, using GTFS schedule dasta and spatial aggregation at the SA2 level.

---

## Indicator 1: Service Intensity (Primary Metric)
### Definition
Average number of stop-time events per weekday per square kilometre.

### Formula
`Service Intensity = (Average weekday stop_time events per SA2) / Area (km2)`

### What it measures

- Practical service availability experienced by passengers
- Combined effect of service frequency + spatial density
- Captures how often public transport arrives within a given area

### Why it matters?

- High-frequency, compact areas (CBD, inner suburbs) surface clearly
- Avoid bias from raw counts by normalising for area
- Suitable for cross-suburb equity comparison

### Key Insight
Service intensity is **strongly concentrated in inner-city SA2s**, indicating spatial imbalance in weekday service provision.

## Indicator 2: Stop-Time Event Volume (Demand-Side)
### Defomotopm
Total number of scheduled stop-time events occurring during active weekday services within a fixed representative period. 

### What it measures

- Volume of scheduled service activity
- Proxy for passenger-visible transport supply
- Reflects how often vehicles arrive at stops

### Why it matters

- Uses GTFS stop_times (most granular schedule unit)
- More representative than route or service coutns alone
- Aligns with "how often can I catch transport?" logic

### Key Insight
Some outer suburbs show moderate service volume but low intensity once area size is considered.

## Indicator 3: Active Service Coverage (Temporal Validaty Filter)

### Definition
Number of weekdays each service_id is active within the analysis period

### What it measures

- Temporal consistency of services
- Prevents overcounting partial or irregular schedules
- Ensures fair comparison across services

### Why it matters

- Filters GTFS services using calendar + weekday logic
- Avoids bias from services active only 1-2 days
- Strengthens analytical reliability

### Key Insight
Weighting by active weekdays produces as more realistic representation of weekday service availability.

## Analst Notes

- Fixed analysis window chosen based on **maximum weekday service overlap**
- Calendar exceptions intentionally excluded to maintain baseline comparability
- Metrics designed for **Tableau Visualisation**
- Scalable methodology applicable to other cities or time windows
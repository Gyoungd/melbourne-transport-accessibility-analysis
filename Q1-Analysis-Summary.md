# Q1 Analysis Summary

## Q1 Business Question
**How equitably is public transport service supplied across Melbourne Suburbs (SA2) during weekdays?**

This analysis evaluates weekday public transport accessibility from a **pessenger-centric perspective**, using GTFS schedule dasta and spatial aggregation at the SA2 level.

---

## Indicator 1: Service Intensity (Primary Metric)
### Definition
Average number of stop-time events per weekday per square kilometre.

### Formula
`Service Intensity = (Average weekday stop_time events per SA2) / Area (km²)`

### What it measures

- Practical service availability experienced by passengers
- Combined effect of service frequency + spatial density
- Captures how often public transport arrives within a given area

### Why it matters?

- High-frequency, compact areas (CBD, inner suburbs) surface clearly
- Avoid bias from raw counts by normalising for area
- Suitable for cross-suburb equity comparison

### Key Insight
Service intensity is **strongly concentrated in inner-city Suburbs(SA2s)**, indicating spatial imbalance in weekday service provision.

## Indicator 2: Stops Density (Supply-Side Infrastructure Metric)
### Definition
Number of unique public transport stops located within each SA2, noirmalised by land area (stops per km²).

### What it measures

- Spatial concentration of physical transport access points
- Infrastructure availability independent of service frequency
- Physical network penetration across suburban geography

### Why it matters

- Controls for suburb size, allowing fair cross-suburb comparison
- Identifies infrastructure gaps in outer growth corridors
- Distinguishes between "network presence" and "operational intensity"
- Servers as a baseline supply-side accessibility metric

### Key Insight
Outer metropolitan suburbs(SA2s) exhibit structurally low stop density once area is normalised, indicating infrastructure under-provision relative to inner-city zones.

## Indicator 3: Route Coverage (Network Connectivity Metric)

### Definition
Number of distinct public transport routes servicing stops within each suburbs(SA2), normalised by land area (routes per km²)

### What it measures

- Network diversity within a suburb
- Structural connectivity beyond stop count
- Availability of alternative travel paths
- Breadth of network integration within local geography

### Why it matters

- Stop density alone may overestimate accessibility
- Higher route coverage implies greater directional flexibility
- Indicates network redundancy and resilience
- Better predictor of service intensity compared to raw stop counts


### Key Insight
Several suburbs show moderate stop density but limited route diversity, suggesting constrained network flexibility despite physical infrastructure presence.

## Analyst Notes

- Analysis window aligned to peak weekday service period to ensure representative baseline conditions
- Calendar exceptions excluded to preserve temporal consistency across suburbs
- MEtrics structured for decision-ready visual analytics and cross-suburb comparability
- Methodology designed for scalability and transferability across cities and timeframes
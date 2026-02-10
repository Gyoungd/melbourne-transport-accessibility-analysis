## Q1. Do measurable public transport accessibility gaps exist between Melbourne suburbs?
    
*Which suburbs are well-served, and which are structurally disadvantaged in terms of access to public transport services?*

**Purpose**

- Identify spaital inequality in service provision
- Establish a baseline for equity-focused planning deicisions

---

### Indicators

#### Stop Density

How close can we access to stops in SA2 (Suburbs)?

**Calculation**

<div style='text-align:center;'>Stop Density = distinct stop count in SA2 / SA2 area (km2)</div><br>


- Assess proximity and convenience for regular commuters
- Identify areas with insufficient stop coverage for safe pedestrian access
- High number of stops $\neq$ High number of travel options
- This indicator means easy accessibility to stops

#### Route Coverage

To what extent is a suburb covered by distinct public transport routes, relative to its geogrphic size?

**Calculation**

<div style = 'text-align:center;'>Route Coverage = (Number of distinct routes in SA2) / (SA2 area in km2)</div><br>


- Stops are first spatially assigned to SA2 boundaries
- Routes are linked via trips → stop_times → stops
- `COUNT(DISTINCT route_id)` is used to avoid inflating coverage by service frequency
- Area normalisation ensures comparability across differently sized suburbs

**Interpretation**

- **Higher route coverage** indicates. 
    - Greater network diversity within the suburb
    - More route-level options available to residents
    - Strong structural connectivity, independent of timetable frequency
- **Lower route coverage** indicates
    - Limited variety of routes serving the area
    - Potential reliance on a small number of corridors
    - Structural undersupply, even if some services run frequently
- It does **not** measure service intensity or frequency

#### Service Intensity

How frequent can we use public per SA2 (Suburbs) during weekday?

**Calculation**

<div style = 'text-align:center;'>Service Intensity = Total stop_time_events_weekday / area_km2</div><br>


*stop_time_events_weekday: number of tirp(transportaions visiting) records per stop during weekday (Mon-Fri) based on stop_times table data*

- Give an insight how frequently public transportation come from the point of passenger view
- stop_times = stop-level schedule event

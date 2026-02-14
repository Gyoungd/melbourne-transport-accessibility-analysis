-- Create table for Choropleth in R
drop table if exists ptv.q1_sa2_metrics;

create table ptv.q1_sa2_metrics as
-- 1. Stop count per sa2
with stops_by_sa2 as(
    select sa2_code,
    count(distinct stop_id) as n_stops
    from ptv.stop_in_sa2
    group by sa2_code
),
-- 2. Distinct routes per sa2
routes_by_sa2 as(
    select 
        s.sa2_code,
        count(distinct t.route_id) as n_routes
    from ptv.stop_in_sa2 s
    join ptv.stop_times st on st.stop_id = s.stop_id
    join ptv.trips t on t.trip_id = st.trip_id
    group by s.sa2_code
),
-- 3. Service Intensity: weighted weekday stop events
service_events_sa2 as(
    select
        s.sa2_code,
        sum(
            (
                coalesce(c.monday, 0) +
                coalesce(c.tuesday, 0) +
                coalesce(c.wednesday, 0) +
                coalesce(c.thursday, 0) +
                coalesce(c.friday, 0)
            )::INT
        )::BIGINT as n_stop_events_week,
        count(*)::BIGINT as n_stop_times_rows
    from ptv.stop_in_sa2 s
    join ptv.stop_times st on st.stop_id = s.stop_id
    join ptv.trips t on t.trip_id = st.trip_id
    join ptv.calendar c on c.service_id = t.service_id
    group by s.sa2_code
)
select
    sb.sa2_code,
    sb.sa2_name,
    sb.area_km2,

    round(coalesce(st.n_stops, 0) / nullif(sb.area_km2,0):: numeric, 6) as stop_density,
    round(coalesce(r.n_routes, 0) / nullif(sb.area_km2,0)::numeric, 6) as route_coverage,

    round((coalesce(se.n_stop_events_week, 0) / 5.0) / nullif(sb.area_km2, 0)::numeric, 6) as service_intensity,

    (coalesce(se.n_stop_times_rows, 0) >0) as has_service_observation,

    sb.geom_4326
from sa2_boundary sb
left join stops_by_sa2 st on st.sa2_code = sb.sa2_code
left join routes_by_sa2 r on r.sa2_code = sb.sa2_code
left join service_events_sa2 se on se.sa2_code=sb.sa2_code;


select * from ptv.q1_sa2_metrics;
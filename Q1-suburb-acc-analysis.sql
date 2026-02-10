--  Create stop_in_sa2: Filter out stops within each SA2 area
drop table if EXISTS ptv.stop_in_sa2;

create table ptv.stop_in_sa2 as(
    select s.stop_id,
    sb.sa2_code,
    sb.sa2_name,
    sb.area_km2,
    sb.geom_7844

    from ptv.sa2_boundary sb
    join ptv.stops s
    on public.st_contains(sb.geom_7844, s.geom_7844)
);

select * from ptv.stop_in_sa2;

-- Stop Density
create table ptv.q1_stop_density as(
with nstops_sa2 as (select sa2_code, sa2_name,
    count(distinct stop_id) as n_stops
from ptv.stop_in_sa2
group by 1,2)
select n.sa2_code,
    n.sa2_name,
    round((n.n_stops::numeric/coalesce(nullif(s.area_km2, 0), 1))::numeric,4) as stop_density
from ptv.stop_in_sa2 s join nstops_sa2 n
on s.sa2_code = n.sa2_code
order by stop_density desc);

select * from ptv.q1_stop_density;

-- Route Coverage
drop table if exists ptv.q1_route_coverage;

create table ptv.q1_route_coverage as (
with route_stop_times as (
    select
        t.route_id,
        s.sa2_code,
        s.sa2_name,
        s.area_km2

    from ptv.stop_in_sa2 s join ptv.stop_times st
    on s.stop_id = st.stop_id
    join ptv.trips t on st.trip_id = t.trip_id
)
select sa2_code, sa2_name,
    count(distinct route_id) as n_routes,
    round(
        count(distinct route_id) /nullif(max(area_km2), 0)::numeric, 4) as route_coverage
from route_stop_times
group by 1,2
order by route_coverage desc);

-- Get the median value of route coverage
select PERCENTILE_CONT(0.5) within group (order by route_coverage) from ptv.q1_route_coverage;

-- Service Intensity
select trip_id, count(*) as n_trip from ptv.stop_times
group by trip_id
having count(*) > 1
order by count(*) desc;

-- Join stop_times & calendar (bridge - trips, based on trip_id)
/*with base_table as (select st.trip_id,
    st.stop_id,
    st.arrival_time,
    st.departure_time,
    st.stop_sequence,
    c.*
from ptv.stop_times st join ptv.trips t on st.trip_id = t.trip_id
join ptv.calendar c on t.service_id = c.service_id
order by st.trip_id, st.arrival_time, st.stop_sequence),
common_period as (  -- 2023-04-24 2023-03-17
select
    max(start_date) as common_start,
    min(end_date) as common_end
from base_table)*/

-- Get the Weekday Intersection
with weekdays as (
    select distinct service_id,
    start_date, end_date, monday, tuesday,
    wednesday, thursday, friday
    from ptv.calendar
),
weekday_sv as(
    select * from weekdays
    where monday = 1 or tuesday =1 or wednesday=1 or thursday=1 or friday=1
)
select max(start_date) as common_start,
    min(end_date) as common_end
from weekday_sv;
-- common start: 2023-04-24 > common end 2023-03-17 => can't use this method

-- Find most overlapping trips date/week => use as an intersection period
-- Find number of active serices per date (weekday only)
with weekdays as (
    select distinct service_id,
    start_date, end_date, monday, tuesday,
    wednesday, thursday, friday
    from ptv.calendar
),
week_span as(
    select gs::date as week_start,
        (gs::date + interval '6 day')::date as week_end
    from generate_series(
        (select min(start_date) from weekdays),
        (select max(end_date) from weekdays),
        interval '1 week'
    ) gs
),
weekdays_in_week as(
    select w.week_start, w.week_end, d::date as d
    from week_span w
    join lateral generate_series(w.week_start, w.week_end, interval '1 day') d on true
    where extract(isodow from d) between 1 and 5
),
active_services_by_week as (
    select wi.week_start,
    wi.week_end,
    count(DISTINCT w.service_id) as active_services
    from weekdays_in_week wi
    join weekdays w
    on wi.d between w.start_date and w.end_date
    and(
        (extract(ISODOW from wi.d)=1 and w.monday=1) OR
        (extract(ISODOW from wi.d)=2 and w.tuesday=1) OR
        (extract(ISODOW from wi.d)=3 and w.wednesday=1) or
        (extract(isodow from wi.d)=4 and w.thursday=1) or
        (extract(isodow from wi.d)=5 and w.friday=1)
    )
    group by wi.week_start, wi.week_end
)
select * from active_services_by_week
order by active_services desc, week_start desc
limit 10;
-- 2023-04-14 ~ 2023-04-20


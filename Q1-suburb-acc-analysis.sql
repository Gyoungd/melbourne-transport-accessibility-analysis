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
-- Fixed Analysis Period: 2023-04-14 ~ 2023-04-20
-- Weekday only
-- Used Tables
    -- stop_time
    -- trips
    -- calendar
    -- stop_in_sa2: filter stops within sa2 area
    -- sa2_boundary: get sa2 area_km2
with params as(
    select 
    date '2023-04-14' as period_start,
    date '2023-04-20' as period_end
),
analysis_date as (
    select d::date as d, extract(isodow from d)::int as isodow
    from params p
    JOIN LATERAL generate_series(p.period_start, p.period_end, interval '1 day') d ON true
    where extract(isodow from d) between 1 and 5 --mon(1) fri(5)
),
-- services within params & weekday
active_services as(
    select distinct c.service_id
    from ptv.calendar c
    join params p on true
    join analysis_date ad
    on ad.d between c.start_date and c.end_date
    and (
        (ad.isodow = 1 and c.monday=1) OR
        (ad.isodow = 2 and c.tuesday=1) OR
        (ad.isodow = 3 and c.wednesday=1) OR
        (ad.isodow = 4 and c.thursday=1) OR
        (ad.isodow = 5 and c.friday=1)
    )
    where c.start_date <=p.period_end and c.end_date >= p.period_start
),
base_events as (
    SELECT
        st.trip_id,
        st.stop_id,
        t.service_id
    from ptv.stop_times st join ptv.trips t on st.trip_id=t.trip_id
    join active_services a on t.service_id=a.service_id
),
-- number of actived day within period per service_id
service_day_counts as(
    SELECT
        c.service_id,
        count(*)::int as active_weekdays
    from ptv.calendar c
    join active_services a on a.service_id = c.service_id
    join analysis_date ad on ad.d between c.start_date and c.end_date
    and (
        (ad.isodow = 1 and c.monday=1) OR
        (ad.isodow = 2 and c.tuesday=1) OR
        (ad.isodow = 3 and c.wednesday=1) OR
        (ad.isodow = 4 and c.thursday=1) OR
        (ad.isodow = 5 and c.friday=1)
    )
    group by c.service_id
),
-- Total number of stop_times event + sa2 mapping
base_events_weighted as (
    select
        be.trip_id,
        be.stop_id,
        be.service_id,
        sdc.active_weekdays
    from base_events be
    join service_day_counts sdc on be.service_id = sdc.service_id
    where sdc.active_weekdays > 0
),
base_events_sa2 as (
    select
        bew.trip_id,
        bew.stop_id,
        bew.service_id,
        bew.active_weekdays,
        si.sa2_code,
        si.sa2_name
    from base_events_weighted bew
    join ptv.stop_in_sa2 si
    on bew.stop_id = si.stop_id
),
-- Get number of services per suburb (weighted by active weekdays)
stop_time_events as(
    select
        sa2_code,
        sa2_name,
        sum(active_weekdays)::bigint as n_stop_events_period
    from base_events_sa2
    group by sa2_code, sa2_name
),
-- To get average service_intensity (daily) since 5 weekday
weekday_cnt as (
    select count(*)::int as n_weekdays from analysis_date
)
SELECT
    ste.sa2_code as suburb_code,
    ste.sa2_name as suburb,
    round((ste.n_stop_events_period / wc.n_weekdays)::numeric, 2) as avg_events_per_weekday,
    round(((ste.n_stop_events_period / wc.n_weekdays) / b.area_km2)::numeric, 2) as service_intensity_per_weekday
FROM
    stop_time_events ste 
    join weekday_cnt wc on true
    join ptv.sa2_boundary b on ste.sa2_code = b.sa2_code
order by service_intensity_per_weekday desc;




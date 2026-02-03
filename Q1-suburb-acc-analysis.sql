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

-- Route Density
with route_stop_times as (
    select st.trip_id,
        st.stop_id,
        t.route_id,
        st.arrival_time,
        st.departure_time,
        st.stop_sequence,
        s.sa2_code,
        s.sa2_name,
        s.area_km2

    from ptv.stop_in_sa2 s left join ptv.stop_times st
    on s.stop_id = st.stop_id
    join ptv.trips t on st.trip_id = t.trip_id
),
route_count as (select sa2_code, sa2_name,
count(distinct route_id) as n_routes
from route_stop_times
group by 1,2
order by count(distinct route_id) desc)
select distinct r.sa2_code,
    r.sa2_name,
    round(r.n_routes / COALESCE(rs.area_km2, 1)::numeric, 4) as route_density
from route_count r join route_stop_times rs on r.sa2_code = rs.sa2_code
order by route_density desc;

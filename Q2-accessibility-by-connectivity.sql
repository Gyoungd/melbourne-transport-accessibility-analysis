-- How different if we analyse accessibility based on the connectivity?
-- Q1 - focused on stop density vs Q2 - focused on connectivity (number of routes serving a stop)

-- Route Connectivity Index (RCI)
-- Within a selected SA2, how various routes can be accessed from different stops.
-- RCI = (Number of unique routes serving stops within the SA2)
-- Analysis required tables
    -- stops
    -- stop_times
    -- trips
    -- routes
    -- sa2_boundary

-- SRID_GEO_SRC = 7844
-- SRID_METER = 7855
-- TRANSFER_M = 250 250 meters walking distance for transfer

-- Build stop geometry (espg: 4326 - for tableau visualisation)
alter table ptv.stops add column if not exists geom_4326 geometry(point, 4326);

update ptv.stops
set geom_4326 = public.st_setsrid(public.st_makepoint(stop_lon, stop_lat), 4326)
where geom_4326 is null;

create index if not exists idx_stops_geom_4326 on ptv.stops using gist (geom_4326);

-- map each stop -> sa2 boundary
-- convert geom_7844 in sa2_boundary to 4326
alter table ptv.sa2_boundary add column if not exists geom_4326 public.geometry(multipolygon, 4326);

select * from ptv.sa2_boundary limit 4;

update ptv.sa2_boundary
set geom_4326 = public.st_multi(public.st_transform(geom_7844, 4326))
where geom_4326 is null;

-- RCI (route connectivity index) by SA2
create table ptv.fact_connectivity_by_sa2 as
with stop_in_sa2 as(
    select 
        b.sa2_code,
        b.sa2_name,
        s.stop_id
    from ptv.sa2_boundary b join ptv.stops s on public.st_contains(b.geom_7844, s.geom_7844)
),
-- stop_id -> route_id / route_type 
stop_route as(
    select s.sa2_code,
    s.sa2_name,
    st.stop_id,
    t.route_id,
    r.route_type
    from stop_in_sa2 s
    join ptv.stop_times st on st.stop_id = s.stop_id
    join ptv.trips t on t.trip_id = st.trip_id
    join ptv.routes r on r.route_id = t.route_id
)
select sa2_code,
    sa2_name,
    count(distinct stop_id) as stops_n,
    count(distinct route_id) as routes_n,
    count(distinct route_type) as route_types_n,
     (count(distinct route_id)::numeric/ nullif(count(distinct stop_id),0)) as routes_per_stop
from stop_route
group by sa2_code, sa2_name;

select * from ptv.fact_connectivity_by_sa2 limit 10;

alter table ptv.fact_connectivity_by_sa2 add primary key (sa2_code);

create index if not EXISTS idx_fact_conn_sa2_name on ptv.fact_connectivity_by_sa2(sa2_name);

analyse ptv.fact_connectivity_by_sa2;
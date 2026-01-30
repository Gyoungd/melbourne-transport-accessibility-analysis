-- Analysis stop density = Number of stops / Area km2
-- Indicators
-- stop_count: Number of stops in the suburb(SAL)
-- stop_density_per_km2: stop_count / area_km2
-- route_count: Number of unique routes passing through the suburb(SAL)
-- mode_mix: Number of unique service per stop in the suburb(SAL) route_type(0/2/3/4)

-- accessibility_supply_idx: stop_density + route_density + transfer_share

-- Step 1: Create SA2 boundary in Melbourne Metropolitan
SET search_path = ptv, public;

create table ptv.sa2_boundary as
select sa2_code21 as sa2_code,
    sa2_name21 as sa2_name,
    ST_UnaryUnion(ST_collect(st_transform(geom, 7844))) as geom_7844
from ptv.mb2021_mel
group by sa2_code21, sa2_name21;

-- Add area_km2 column by calcuating area of geom_7844
alter table ptv.sa2_boundary add column area_km2 double precision;

update ptv.sa2_boundary
set area_km2 = st_area(st_transform(geom_7844, 7855)) / 1000000; -- in km2, EPSG: 7855 for area calculation

select * from ptv.sa2_boundary limit 4;

create index if not exists idx_sa2_boundary_geom
on ptv.sa2_boundary using gist (geom_7844);

-- Step 2: Add Point geom in 'stops' table
alter table ptv.stops add column geom_4326 public.geometry(point, 4326);

UPDATE ptv.stops
SET geom_4326 = public.ST_SetSRID(
    public.ST_MakePoint(stop_lon, stop_lat),
    4326
)
WHERE geom_4326 IS NULL;

select * from ptv.stops limit 4;

-- Convert Stops geom to 7844 to match SA2 boundary
alter table ptv.stops add column geom_7844 public.geometry(point, 7844);

update ptv.stops
set geom_7844 = st_transform(geom_4326, 7844)
where geom_7844 is null;

create index idx_stops_geom_7844
on ptv.stops using gist (geom_7844);

-- Step 3: Defines Indicators for Q1 Suburb Accessibility Gap Analysis
-- 1. Stop Density
-- 2. Route Coverage: Number of distinct route_id in the suburb
-- 3. Service intensity (Approx.): Number of records in stop_times for the stops in the suburb

-- fact_accessibility_by_sa2
drop table if exists ptv.fact_accessibility_by_sa2;

select * from ptv.sa2_boundary limit 4;

create table ptv.fact_accessibility_by_sa2 as
with stop_in_sa2 as(
    select
        b.sa2_code,
        b.sa2_name,
        s.stop_id
    from ptv.sa2_boundary b join ptv.stops s on public.st_contains(b.geom_7844, s.geom_7844)
),
stop_counts as(
    select sa2_code,
        count(distinct t.stop_id) as stop_count
    from stop_in_sa2 t
    group by sa2_code
),
-- stops -> stop_times -> trips -> routes
route_counts as(
    select
        si.sa2_code,
        count(distinct t.route_id) as route_count
    from stop_in_sa2 si
    join ptv.stop_times st on st.stop_id = si.stop_id
    join ptv.trips tr on tr.trip_id = st.trip_id
    join ptv.routes t on t.route_id = tr.route_id
    group by si.sa2_code
),
service_intensity as(
    select si.sa2_code,
        count(*) as stop_time_events
        from stop_in_sa2 si
        join ptv.stop_times st on si.stop_id = st.stop_id
        group by si.sa2_code
)
select
    b.sa2_code,
    b.sa2_name,
    b.area_km2,
    coalesce(sc.stop_count, 0) as stop_count,
    Round(coalesce(sc.stop_count, 0)::numeric/ nullif(b.area_km2,0), 4) as stop_density_per_km2,
    coalesce(rc.route_count, 0) as route_count,
    coalesce(si.stop_time_events, 0) as stop_time_events,
    b.geom_7844
from ptv.sa2_boundary b
left join stop_counts sc on sc.sa2_code = b.sa2_code
left join route_counts rc on sc.sa2_code = b.sa2_code
left join service_intensity si on si.sa2_code = b.sa2_code; 

select * from ptv.fact_accessibility_by_sa2
where lower(sa2_name) like lower('%glen%') limit 3;

-- Check the srid of geom_7844
select distinct public.st_srid(geom_7844) as srid from ptv.fact_accessibility_by_sa2;

alter table ptv.fact_accessibility_by_sa2
add column geom_wkt_4326 text;

select * from ptv.fact_accessibility_by_sa2 limit 4;

DROP TABLE IF EXISTS ptv.fact_accessibility_by_sa2_4326;
alter table ptv.fact_accessibility_by_sa2
add column geom_4326 public.geometry(multipolygon, 4326);

select sa2_code, sa2_name, count(*) from ptv.fact_accessibility_by_sa2
group by sa2_code, sa2_name
having count(*) > 1;

select * from ptv.fact_accessibility_by_sa2 limit 5;

-- Prep Tableau visualisation ver table
drop table if exists ptv.agg_q1_acc_sa2;

-- region_type: From CBD, distance base
-- accessibility_score: min-max normalised indicators


SET search_path = ptv, public;

create table ptv.agg_q1_acc_sa2 as
with base as(
    select sa2_code,
        sa2_name,
        area_km2,
        stop_count,
        stop_density_per_km2,
        route_count,
        stop_time_events,
        geom_7844
    from ptv.fact_accessibility_by_sa2
),
analysis as(
    select
        b.sa2_code,
        b.sa2_name,
        b.area_km2,
        b.stop_count,
        b.stop_density_per_km2,
        b.route_count,
        b.stop_time_events,
        b.geom_7844,
        round((b.route_count::numeric / nullif(b.area_km2 ::numeric, 0::numeric)), 4) as route_density_per_km2,         -- Additional density indicator
        round((b.stop_time_events::numeric / nullif(b.area_km2::numeric, 0::numeric)),4) as stop_time_events_density_per_km2,

        st_y(public.st_transform(public.st_pointonsurface(b.geom_7844), 4326))::double precision as centroid_lat, -- centroid (lon, lat)
        st_x(public.st_transform(public.st_pointonsurface(b.geom_7844), 4326))::double precision as centroid_lon,
        round(
            (public.st_distance(
                public.st_transform(public.st_pointonsurface(b.geom_7844), 4326)::geography,        -- CBD distance(km) -> create region_type
                public.st_setSRID(public.st_makepoint(144.9631, -37.8136), 4326)::geography
            ) / 1000.0)::numeric 
        ,2) as dist_to_cbd_km
    from base b
),
normalisation_bounds as(
    SELECT
        min(stop_density_per_km2) as min_stop_den,
        max(stop_density_per_km2) as max_stop_den,

        min(route_density_per_km2) as min_route_den,
        max(route_density_per_km2) as max_route_den,

        min(stop_time_events_density_per_km2) as min_evt_den,
        max(stop_time_events_density_per_km2) as max_evt_den

    FROM analysis
),
scored as (
    select
        a.sa2_code,
        a.sa2_name,
        a.area_km2,

        a.stop_count,
        a.stop_density_per_km2,
        a.route_count,
        a.route_density_per_km2,
        a.stop_time_events,
        a.stop_time_events_density_per_km2,

        a.centroid_lat,
        a.centroid_lon,
        a.dist_to_cbd_km,

        CASE 
            WHEN a.dist_to_cbd_km <= 10 THEN 'Inner'
            WHEN a.dist_to_cbd_km <= 25 THEN 'Middle'  
            ELSE  'Outer'
        END as region_type,

        CASE            -- min-max normalise (0-1)
            WHEN (nb.max_stop_den - nb.min_stop_den) = 0 THEN 0  
            ELSE (a.stop_density_per_km2 - nb.min_stop_den) / (nb.max_stop_den - nb.min_stop_den)
        END as norm_stop_density,

        CASE 
            WHEN (nb.max_route_den - nb.min_route_den) =0 THEN 0  
            ELSE (a.route_density_per_km2 - nb.min_route_den) / (nb.max_route_den - nb.min_route_den)
        END as norm_route_density,

        CASE 
            WHEN (nb.max_evt_den - nb.min_evt_den) = 0 THEN 0  
            ELSE (a.stop_time_events_density_per_km2 - nb.min_evt_den) / (nb.max_evt_den - nb.min_evt_den)
        END as norm_event_density
    from analysis a
    cross join normalisation_bounds nb

),
final as (
    SELECT
        s.*,
        round(    -- Composite score
            (0.4 * s.norm_stop_density +
            0.3 * s.norm_route_density +
            0.3 * s.norm_event_density
            )::NUMERIC
        , 4) as accessibility_score
    from scored s
)
SELECT
    f.sa2_code,
    f.sa2_name,
    f.region_type,

    f.area_km2,

    f.stop_count,
    f.stop_density_per_km2,

    f.route_count,
    f.route_density_per_km2,

    f.stop_time_events,
    f.stop_time_events_density_per_km2,

    f.accessibility_score,

    dense_rank() over (order by f.accessibility_score desc) as accessibility_rank,      -- rank/quantile
    ntile(5) over (order by f.accessibility_score desc) as accessibility_quantile,

    round(   -- Gap based on AVG
        (
            (f.accessibility_score - avg(f.accessibility_score) over())
            / nullif(avg(f.accessibility_score) over(), 0)
        )::numeric
    ,4) as gap_vs_trans_avg_ratio,

    f.centroid_lat,     -- for map vis
    f.centroid_lon,
    f.dist_to_cbd_km
from final f;


select
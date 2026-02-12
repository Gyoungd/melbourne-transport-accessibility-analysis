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


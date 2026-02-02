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

select * from ptv.sa2_boundary;

-- Add geom column for choropleth map vis

alter table ptv.q1_stop_density add column geom public.geometry(multipolygon, 7844);

update ptv.q1_stop_density q
set geom = b.geom_7844
from ptv.sa2_boundary b
where q.sa2_code = b.sa2_code;

select * from ptv.q1_stop_density;

select percentile_cont(0.5) within group (order by stop_density) from ptv.q1_stop_density;

select distinct sa2_code, sa2_name, stop_density from ptv.q1_stop_density order by stop_density limit 15;

-- Route Density


-- Active: 1769411022170@@crossover.proxy.rlwy.net@44328@railway@ptv
 -- Create Melbourne Mesh Blocks Table

select * from ptv.mb_2021;

-- Extract mesh blocks only in Melbourne Metropolitan Area (mb2021_mel)
create table ptv.mb2021_mel as(
    select * from ptv.mb_2021
    where upper(gcc_name21) = upper('greater melbourne')
);

select * from ptv.mb2021_mel;

-- Get a polygon for the boundary of Melbourne Metropolitan
create table ptv.mel_boundary as
select ST_Union(geom) as geom
from ptv.mb2021_mel;

select * from ptv.mel_boundary;

-- Get area(km2)
select st_area(st_transform(geom, 7855)) /1000000 as area_km2
from ptv.mel_boundary;

SET search_path = ptv, public;

-- Create Melbourne LGA Table (lga2021_mel)
create table ptv.lag2021_mel as(
    select l.*, m.geom from ptv.lga_2021 l
    join ptv.mb2021_mel m on l.mb_code = m.mb_code21
);

select * from ptv.lag2021_mel;

-- Filter out Melbourne LGAs only in suburb area (sal2021_mel)

create table ptv.sal2021_mel as(
    select
    s.mb_code,
    s.sal_code,
    s.sal_name,
    s.state_name,
    s.aus_name,
    s.area_albers_sqkm as area_km2,
    m.geom from ptv.sal_2021 s
    join ptv.mb2021_mel m on s.mb_code = m.mb_code21
);

-- Create the SAL boundary
SET search_path = ptv, public;

create table ptv.sal_boundary_mel as
select
    mb_code,
    sal_code,
    sal_name,
    MAX(area_km2) as area_km2,
    st_unaryunion(st_collect(st_transform(geom, 7855)))::geometry(multipolygon, 7855) as geom
    from ptv.sal2021_mel
    group by 1,2,3;


select sal_name, count(*) as n from ptv.sal_boundary_mel
group by sal_name
order by n desc;

create index idx_sal_boundary_mel_geom
on ptv.sal_boundary_mel using GIST (geom);

select * from ptv.sal_boundary_mel;
with footprints_county as (
select 
f."release",
f."capture_dates_range",
f."geometry",
c."GEOID",
c."NAMELSAD"
from raw_dev.building_footprints.california_building_footprints f
left join raw_dev.tiger_2022.counties c
on st_intersects(f."geometry", c."geometry")
)
select * from footprints_county
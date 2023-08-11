with footprints_tract as (
    select 
f."release",
f."capture_dates_range",
f."geometry",
t."GEOID",
t."NAMELSAD"
from raw_dev.building_footprints.california_building_footprints f
left join raw_dev.tiger_2022.tracts t
on st_intersects(f."geometry", t."geometry")
)

select * from footprints_tract
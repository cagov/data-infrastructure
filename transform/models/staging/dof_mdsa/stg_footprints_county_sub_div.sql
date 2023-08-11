with footprints_sub_div as (
    select 
f."release",
f."capture_dates_range",
f."geometry",
cs."GEOID",
cs."NAMELSAD"
from raw_dev.building_footprints.california_building_footprints f
left join raw_dev.tiger_2022.county_subdivisions cs
on st_intersects(f."geometry", cs."geometry")
)

select * from footprints_sub_div
with footprints_block as (
    select 
f."release",
f."capture_dates_range",
f."geometry",
b."GEOID20",
b."NAME20"
from raw_dev.building_footprints.california_building_footprints f
left join raw_dev.tiger_2022.blocks b
on st_intersects(f."geometry", b."geometry")
)

select * from footprints_block
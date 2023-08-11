with footprints_block_grp as (
    select 
f."release",
f."capture_dates_range",
f."geometry",
bg."GEOID",
bg."NAMELSAD"
from raw_dev.building_footprints.california_building_footprints f
left join raw_dev.tiger_2022.block_groups bg
on st_intersects(f."geometry", bg."geometry")
)

select * from footprints_block_grp
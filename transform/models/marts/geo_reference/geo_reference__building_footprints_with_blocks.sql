with footprints as (
    select * from {{ source('building_footprints', 'california_building_footprints') }}
),

blocks_source as (
    select * from {{ source('tiger_2022', 'blocks') }}
),

blocks as (
    select
        "COUNTYFP20" as "county_fips",
        "TRACTCE20" as "tract",
        "BLOCKCE20" as "block",
        "GEOID20" as "geoid",
        "NAME20" as "name",
        "geometry"
    from blocks_source
),

footprints_and_blocks_joined as (
    {{ spatial_join_with_deduplication(
       "footprints",
       "blocks",
       ['"release"', '"capture_dates_range"'],
       ['"county_fips"', '"tract"', '"block"', '"geoid"', '"name"'],
       left_geom='"geometry"',
       right_geom='"geometry"',
    ) }}
)

select * from footprints_and_blocks_joined

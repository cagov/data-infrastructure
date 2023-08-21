with footprints as (
    select
        "release",
        "capture_dates_range",
        "geometry"
    from {{ source('building_footprints', 'california_building_footprints') }}
),

blocks_source as (
    select * from {{ source('tiger_2022', 'blocks') }}
),

blocks_renamed as (
    select
        "COUNTYFP20" as "county_fips",
        "TRACTCE20" as "tract",
        "BLOCKCE20" as "block",
        "GEOID20" as "geoid",
        "NAME20" as "name",
        "UR20" as "urban_rural_area",
        "geometry"
    from blocks_source
),

blocks as (
    select
        "county_fips",
        "tract",
        "block",
        "geoid",
        "name",
        "urban_rural_area",
        "geometry"
    from blocks_renamed
),

footprints_and_blocks_joined as (
    select
        footprints.*,
        blocks.* exclude "geometry"
    from footprints
    left join blocks on st_intersects(footprints."geometry", blocks."geometry")
)

select * from footprints_and_blocks_joined

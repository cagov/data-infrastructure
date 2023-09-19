with footprints as (
    select
        1 as "height",
        "geometry"
    from {{ source('building_footprints', 'global_ml_building_footprints') }}
),

blocks_source as (
    select *
    from {{ source('tiger_2022', 'blocks') }}
),

places_source as (
    select * from {{ source('tiger_2022', 'places') }}
),

blocks as (
    select
        "COUNTYFP20" as "county_fips",
        "TRACTCE20" as "tract",
        "BLOCKCE20" as "block",
        "GEOID20" as "block_geoid",
        "geometry"
    from blocks_source
),

places as (
    select
        "PLACEFP" as "place_fips",
        "PLACENS" as "place_ns",
        "GEOID" as "place_geoid",
        "NAME" as "place_name",
        "CLASSFP" as "class_fips_code",
        {{ map_class_fips("CLASSFP") }} as "class_fips",
        "geometry"
    from places_source
),

footprints_with_blocks as (
    {{ spatial_join_with_deduplication(
       "footprints",
       "blocks",
       ['"height"'],
       ['"county_fips"', '"tract"', '"block"', '"block_geoid"'],
       left_geom='"geometry"',
       right_geom='"geometry"',
       kind="inner",
       prefix="b",
    ) }}
),

footprints_with_blocks_and_places as (
    {{ spatial_join_with_deduplication(
       "footprints_with_blocks",
       "places",
       ['"height"', '"county_fips"', '"tract"', '"block"', '"block_geoid"'],
       ['"place_fips"', '"place_ns"', '"place_geoid"', '"place_name"', '"class_fips_code"', '"class_fips"'],
       left_geom='"geometry"',
       right_geom='"geometry"',
       kind="left",
       prefix="p",
    ) }}
)

select * from footprints_with_blocks_and_places

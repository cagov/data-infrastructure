with footprints as ( -- noqa: ST03
    select
        "height",
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

blocks as ( -- noqa: ST03
    select
        countyfp20 as "county_fips",
        tractce20 as "tract",
        blockce20 as "block",
        geoid20 as "block_geoid",
        "geometry"
    from blocks_source
),

places as ( -- noqa: ST03
    select
        placefp as "place_fips",
        placens as "place_ns",
        geoid as "place_geoid",
        name as "place_name",
        classfp as "class_fips_code",
        {{ map_class_fips("CLASSFP") }} as "class_fips",
        "geometry"
    from places_source
),

footprints_with_blocks as ( -- noqa: ST03
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
),

footprints_with_blocks_and_places_final as (
    select
        *,
        st_area("geometry") as "area_sqm"
    from footprints_with_blocks_and_places
)

select * from footprints_with_blocks_and_places_final

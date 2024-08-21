with blocks_source as (
    select *
    from {{ source('tiger_2022', 'blocks') }}
),

places_source as (
    select * from {{ source('tiger_2022', 'places') }}
),

footprints_with_blocks_and_places as (
    {{ spatial_join_with_deduplication(
       "footprints_with_blocks",
       "places",
       ['"release"', '"capture_dates_range"', '"county_fips"', '"tract"', '"block"', '"block_geoid"'],
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

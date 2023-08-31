with footprints as (
    select * from {{ source('building_footprints', 'california_building_footprints') }}
),

places_source as (
    select * from {{ source('tiger_2022', 'places') }}
),

places as (
    select
        "PLACEFP" as "place_fp",
        "PLACENS" as "place_ns",
        "GEOID" as "geoid",
        "NAME" as "name",
        "CLASSFP" as "class_fips_code",
        {{ map_class_fips("CLASSFP") }} as "class_fips",
        "geometry"
    from places_source
),

footprints_and_places_joined as (
    {{ spatial_join_with_deduplication(
       "footprints",
       "places",
       ['"release"', '"capture_dates_range"'],
       ['"place_fp"', '"place_ns"', '"geoid"', '"name"', '"class_fips_code"', '"class_fips"'],
       left_geom='"geometry"',
       right_geom='"geometry"',
    ) }}
)

select * from footprints_and_places_joined

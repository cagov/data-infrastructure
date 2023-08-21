with footprints as (
    select
        "release",
        "capture_dates_range",
        "geometry"
    from {{ source('building_footprints', 'california_building_footprints') }}
),

places_source as (
    select * from {{ source('tiger_2022', 'places') }}
),

places_renamed as (
    select
        "PLACEFP" as "place_fp",
        "PLACENS" as "place_ns",
        "GEOID" as "geoid",
        "NAME" as "name",
        "CLASSFP" as "class_fips_code",
        "geometry"
    from places_source
),

places as (
    select
        "place_fp",
        "place_ns",
        "geoid",
        "name",
        "class_fips_code",
        {{ map_class_fips("class_fips_code") }} as "class_fips",
        "geometry"
    from places_renamed
),

footprints_and_places_joined as (
    select
        footprints.*,
        places.* exclude "geometry"
    from footprints
    left join places on st_intersects(footprints."geometry", places."geometry")
)

select * from footprints_and_places_joined

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
    select
        footprints.*,
        places.* exclude "geometry"
    from footprints
    left join places on st_intersects(footprints."geometry", places."geometry")
)

select * from footprints_and_places_joined

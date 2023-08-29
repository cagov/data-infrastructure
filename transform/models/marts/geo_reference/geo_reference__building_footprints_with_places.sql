with footprints as (
    select
        "release",
        "capture_dates_range",
        "geometry",
        /* Generate a temporary ID for footprints. We will need this to group/partition
        by unique footprints further down. We could use a UUID, but integers are
        cheaper to generate and compare. */
        seq4() as _tmp_id
    from {{ source('building_footprints', 'california_building_footprints') }}
),

places_source as (
    select * from {{ source('tiger_2022', 'places') }}
),

places as (
    select
        "PLACEFP" as "place_fips",
        "PLACENS" as "place_gnis",
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
        places.* exclude "geometry",
        /* We don't actually need the intersection for every footprint, only for the
         ones that intersect more than one place. However, in order to establish which
         ones intersect more than one place, we need a windowed COUNT partitioned by
         _tmp_id. This is an expensive operation, as it likely triggers a shuffle
         (even though it should already be sorted by _tmp_id). In testing we've found
         that it's cheaper to just do the intersection for all the footprints. */
        st_area(st_intersection(footprints."geometry", places."geometry"))
            as _tmp_intersection
    from footprints
    left join places on st_intersects(footprints."geometry", places."geometry")
),

footprints_and_places_joined_dedupe as (
    select
        -- Snowflake doesn't support geometries in max_by. It should, but it doesn't.
        -- Fortunately, we know that the geometries are identical when partitioned
        -- by _tmp_id, so we can just choose any_value.
        any_value("geometry") as "geometry",
        max_by("place_fips", _tmp_intersection) as "place_fips",
        max_by("place_gnis", _tmp_intersection) as "place_gnis",
        max_by("name", _tmp_intersection) as "name",
        max_by("geoid", _tmp_intersection) as "geoid",
        max_by("class_fips_code", _tmp_intersection) as "class_fips_code",
        max_by("class_fips", _tmp_intersection) as "class_fips"
    from footprints_and_places_joined
    where "place_fips" is not null
    group by _tmp_id

)

select * from footprints_and_places_joined_dedupe

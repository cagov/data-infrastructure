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
    select
        footprints.*,
        blocks.* exclude "geometry",
        /* We don't actually need the intersection for every footprint, only for the
         ones that intersect more than one block. However, in order to establish which
         ones intersect more than one block, we need a windowed COUNT partitioned by
         _tmp_id. This is an expensive operation, as it likely triggers a shuffle
         (even though it should already be sorted by _tmp_id). In testing we've found
         that it's cheaper to just do the intersection for all the footprints. */
        st_area(st_intersection(footprints."geometry", blocks."geometry"))
            as _tmp_intersection
    from footprints
    left join blocks on st_intersects(footprints."geometry", blocks."geometry")
),

footprints_and_blocks_joined_dedupe as (
    select
        -- Snowflake doesn't support geometries in max_by. It should, but it doesn't.
        -- Fortunately, we know that the geometries are identical when partitioned
        -- by _tmp_id, so we can just choose any_value.
        any_value("geometry") as "geometry",
        max_by("county_fips", _tmp_intersection) as "county_fips",
        max_by("tract", _tmp_intersection) as "tract",
        max_by("block", _tmp_intersection) as "block",
        max_by("geoid", _tmp_intersection) as "geoid",
        max_by("name", _tmp_intersection) as "name"
    from footprints_and_blocks_joined
    group by _tmp_id
)

select * from footprints_and_blocks_joined_dedupe

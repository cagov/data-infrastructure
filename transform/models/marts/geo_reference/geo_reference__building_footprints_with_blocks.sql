with footprints as (
    select
        "release",
        "capture_dates_range",
        "geometry",
        -- TODO: is seq4() superior to to uuid_string()? It should be able
        -- to improve the partitioning below based on micropartition logic.
        -- but in practice the difference doesn't seem large.
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
        -- TODO: investigate how much savings there are by doing this with
        -- a `case` statement rather than computing the area for everything.
        -- also investigate whether there are any savings to be had doing
        -- this with a self join instead of a window function.
        case count(*) over (partition by footprints._tmp_id) > 1
            when false then 1.0
            when
                true
                then st_area(st_intersection(footprints."geometry", blocks."geometry"))
        end as _tmp_intersection
    from footprints
    left join blocks on st_intersects(footprints."geometry", blocks."geometry")
),

-- TODO: investigate the performance characteristics of using the window
-- function approach vs the max_by approach.
footprints_and_blocks_joined_dedupe as (
    select *
    from footprints_and_blocks_joined
    qualify row_number() over (partition by _tmp_id order by _tmp_intersection desc) = 1
),

footprints_and_blocks_joined_dedupe2 as (
    select
        any_value("geometry") as "geometry",
        max_by("county_fips", _tmp_intersection) as "county_fips",
        max_by("tract", _tmp_intersection) as "tract",
        max_by("block", _tmp_intersection) as "block",
        max_by("geoid", _tmp_intersection) as "geoid",
        max_by("name", _tmp_intersection) as "name"
    from footprints_and_blocks_joined
    group by _tmp_id
)

select * from footprints_and_blocks_joined_dedupe2

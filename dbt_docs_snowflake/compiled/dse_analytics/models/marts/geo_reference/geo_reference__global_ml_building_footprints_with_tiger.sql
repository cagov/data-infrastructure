with footprints as ( -- noqa: ST03
    select
        "height",
        "geometry"
    from RAW_DEV.building_footprints.global_ml_building_footprints
),

blocks_source as (
    select *
    from RAW_DEV.tiger_2022.blocks
),

places_source as (
    select * from RAW_DEV.tiger_2022.places
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
        

case
    when "CLASSFP" = 'M2'
    then 'A military or other defense installation entirely within a place'
    when "CLASSFP" = 'C1'
    then 'An active incorporated place that does not serve as a county subdivision equivalent'
    when "CLASSFP" = 'U1'
    then 'A census designated place with an official federally recognized name'
    when "CLASSFP" = 'U2'
    then 'A census designated place without an official federally recognized name'
    end as "class_fips",
        "geometry"
    from places_source
),

footprints_with_blocks as ( -- noqa: ST03
    

with b_left_model_with_id as (
    select
        /* Generate a temporary ID for footprints. We will need this to group/partition
        by unique footprints further down. We could use a UUID, but integers are
        cheaper to generate and compare. */
        *, seq4() as _tmp_sjoin_id
    from footprints
),

b_joined as (
    select
      b_left_model_with_id."height",
      blocks."county_fips",
      blocks."tract",
      blocks."block",
      blocks."block_geoid",
      b_left_model_with_id."geometry",
      /* We don't actually need the intersection for every geometry, only for the
       ones that intersect more than one. However, in order to establish which
       ones intersect more than one, we need a windowed COUNT partitioned by
       _tmp_sjoin_id. This is an expensive operation, as it likely triggers a shuffle
       (even though it should already be sorted by _tmp_id). In testing we've found
       that it's cheaper to just do the intersection for all the geometries. */
      st_area(
        st_intersection(b_left_model_with_id."geometry", blocks."geometry")
      ) as _tmp_sjoin_intersection,
      b_left_model_with_id._tmp_sjoin_id
    from b_left_model_with_id
    inner join blocks
    on st_intersects(b_left_model_with_id."geometry", blocks."geometry")
),

b_deduplicated as (
    select
      -- Snowflake doesn't support geometries in max_by. It should, but it doesn't.
      -- Fortunately, we know that the geometries are identical when partitioned
      -- by _tmp_sjoin_id, so we can just choose any_value.
      any_value("geometry") as "geometry",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("height", coalesce(_tmp_sjoin_intersection, 1.0)) as "height",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("county_fips", coalesce(_tmp_sjoin_intersection, 1.0)) as "county_fips",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("tract", coalesce(_tmp_sjoin_intersection, 1.0)) as "tract",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("block", coalesce(_tmp_sjoin_intersection, 1.0)) as "block",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("block_geoid", coalesce(_tmp_sjoin_intersection, 1.0)) as "block_geoid"
      from b_joined
    group by _tmp_sjoin_id
)

select * from b_deduplicated
),

footprints_with_blocks_and_places as (
    

with p_left_model_with_id as (
    select
        /* Generate a temporary ID for footprints. We will need this to group/partition
        by unique footprints further down. We could use a UUID, but integers are
        cheaper to generate and compare. */
        *, seq4() as _tmp_sjoin_id
    from footprints_with_blocks
),

p_joined as (
    select
      p_left_model_with_id."height",
      p_left_model_with_id."county_fips",
      p_left_model_with_id."tract",
      p_left_model_with_id."block",
      p_left_model_with_id."block_geoid",
      places."place_fips",
      places."place_ns",
      places."place_geoid",
      places."place_name",
      places."class_fips_code",
      places."class_fips",
      p_left_model_with_id."geometry",
      /* We don't actually need the intersection for every geometry, only for the
       ones that intersect more than one. However, in order to establish which
       ones intersect more than one, we need a windowed COUNT partitioned by
       _tmp_sjoin_id. This is an expensive operation, as it likely triggers a shuffle
       (even though it should already be sorted by _tmp_id). In testing we've found
       that it's cheaper to just do the intersection for all the geometries. */
      st_area(
        st_intersection(p_left_model_with_id."geometry", places."geometry")
      ) as _tmp_sjoin_intersection,
      p_left_model_with_id._tmp_sjoin_id
    from p_left_model_with_id
    left join places
    on st_intersects(p_left_model_with_id."geometry", places."geometry")
),

p_deduplicated as (
    select
      -- Snowflake doesn't support geometries in max_by. It should, but it doesn't.
      -- Fortunately, we know that the geometries are identical when partitioned
      -- by _tmp_sjoin_id, so we can just choose any_value.
      any_value("geometry") as "geometry",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("height", coalesce(_tmp_sjoin_intersection, 1.0)) as "height",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("county_fips", coalesce(_tmp_sjoin_intersection, 1.0)) as "county_fips",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("tract", coalesce(_tmp_sjoin_intersection, 1.0)) as "tract",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("block", coalesce(_tmp_sjoin_intersection, 1.0)) as "block",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("block_geoid", coalesce(_tmp_sjoin_intersection, 1.0)) as "block_geoid",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("place_fips", coalesce(_tmp_sjoin_intersection, 1.0)) as "place_fips",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("place_ns", coalesce(_tmp_sjoin_intersection, 1.0)) as "place_ns",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("place_geoid", coalesce(_tmp_sjoin_intersection, 1.0)) as "place_geoid",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("place_name", coalesce(_tmp_sjoin_intersection, 1.0)) as "place_name",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("class_fips_code", coalesce(_tmp_sjoin_intersection, 1.0)) as "class_fips_code",
      -- max_by returns null if all the values in a group are null. So if we have a left
      -- join, we need to guard against nulls with a coalesce to return the single value
      max_by("class_fips", coalesce(_tmp_sjoin_intersection, 1.0)) as "class_fips"
      from p_joined
    group by _tmp_sjoin_id
)

select * from p_deduplicated
),

footprints_with_blocks_and_places_final as (
    select
        *,
        st_area("geometry") as "area_sqm"
    from footprints_with_blocks_and_places
)

select * from footprints_with_blocks_and_places_final
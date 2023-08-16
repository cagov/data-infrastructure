with footprints as (
    select
        "release",
        "capture_dates_range",
        "geometry"
    from {{ ref('stg_building__footprints') }}
),

blocks as (
    select
        "county_fp",
        "tract_ce",
        "block_ce",
        "geo_id",
        "name",
        "maf_tiger_feature_class_code",
        "maf_tiger_feature_class",
        "urban_rural_area",
        "housing_unit_count",
        "pop_count",
        "geometry"
    from {{ ref('int_geo_reference_blocks__mapped') }}
),

footprints_and_blocks_joined as (
    select
        footprints.*,
        blocks."county_fp",
        blocks."tract_ce",
        blocks."block_ce",
        blocks."geo_id",
        blocks."name",
        blocks."maf_tiger_feature_class_code",
        blocks."maf_tiger_feature_class",
        blocks."urban_rural_area",
        blocks."housing_unit_count",
        blocks."pop_count"
    from footprints
    left join blocks on st_intersects(footprints."geometry", blocks."geometry")
)

select * from footprints_and_blocks_joined

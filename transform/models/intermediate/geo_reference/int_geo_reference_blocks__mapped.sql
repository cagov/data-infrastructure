with blocks as (
    select
        "county_fp",
        "tract_ce",
        "block_ce",
        "geo_id",
        "name",
        "maf_tiger_feature_class_code",
        {{ map_maf_tiger_feature_class("maf_tiger_feature_class_code") }}
            as "maf_tiger_feature_class",
        "urban_rural_area",
        "housing_unit_count",
        "pop_count",
        "geometry"
    from {{ ref('stg__blocks') }}
)

select * from blocks

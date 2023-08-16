with places as (
    select
        "place_fp",
        "place_ns",
        "geo_id",
        "name",
        "class_fp_code",
        {{ map_class_fp("class_fp_code") }} as "class_fp",
        "maf_tiger_feature_class_code",
        {{ map_maf_tiger_feature_class("maf_tiger_feature_class_code") }}
            as "maf_tiger_feature_class",
        "geometry"
    from {{ ref('stg__places') }}
)

select * from places

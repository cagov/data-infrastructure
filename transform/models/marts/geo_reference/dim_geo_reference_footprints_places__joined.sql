with footprints as (
    select
        "release",
        "capture_dates_range",
        "geometry"
    from {{ ref('stg_building__footprints') }}
),

places as (
    select
        "place_fp",
        "place_ns",
        "geo_id",
        "name",
        "class_fp_code",
        "class_fp",
        "maf_tiger_feature_class_code",
        "maf_tiger_feature_class",
        "geometry"
    from {{ ref('int_geo_reference_places__mapped') }}
),


footprints_and_places_joined as (
    select
        footprints.*,
        places."place_fp",
        places."place_ns",
        places."geo_id",
        places."name",
        places."class_fp_code",
        places."class_fp",
        places."maf_tiger_feature_class_code",
        places."maf_tiger_feature_class"
    from footprints
    left join places on st_intersects(footprints."geometry", places."geometry")
)

select * from footprints_and_places_joined

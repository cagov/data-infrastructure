with source as (
    select * from {{ source('tiger_2022', 'places') }}
),

staged as (
    select
        "PLACEFP" as "place_fp",
        "PLACENS" as "place_ns",
        "GEOID" as "geo_id",
        "NAME" as "name",
        "CLASSFP" as "class_fp_code",
        "MTFCC" as "maf_tiger_feature_class_code",
        "geometry"
    from source
)

select * from staged

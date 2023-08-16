with source as (
    select * from {{ source('tiger_2022', 'places') }}
),

staged as (
    select
        "GEOID" as "geo_id",
        "NAME" as "name",
        "CLASSFP" as "class_fp",
        "MTFCC" as "maf_tiger_feature_class_code"
    from source
)

select * from staged

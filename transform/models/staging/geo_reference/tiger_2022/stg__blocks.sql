with source as (
    select * from {{ source('tiger_2022', 'blocks') }}
),

staged as (
    select
        "COUNTYFP20" as "county_fp",
        "TRACTCE20" as "tract_ce",
        "BLOCKCE20" as "block_ce",
        "GEOID20" as "geo_id",
        "NAME20" as "name",
        "UR20" as "urban_rural_area",
        "HOUSING20" as "housing_unit_count",
        "HOUSING20" as "pop_count"
    from source
)

select * from staged

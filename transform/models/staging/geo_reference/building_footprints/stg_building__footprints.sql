with source as (
    select * from {{source('building_footprints', 'california_building_footprints')}}
),

staged as (
    select
        "release",
        "capture_dates_range",
        "geometry"
    from source
)

select * from staged
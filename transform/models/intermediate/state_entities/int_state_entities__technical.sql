{{ config(materialized="view") }}

with
    technical_entities as (
        select *
        from {{ ref("stg_department_of_finance__entities") }}
        where
            (do_not_use = false and abolished = false)
            and (restricted_use is not null or cast(primary_code as int) >= 9000)
    )

select *
from technical_entities

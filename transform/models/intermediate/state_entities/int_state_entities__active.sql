{{ config(materialized="view") }}

with
active_entities as (
    select *
    from {{ ref("stg_department_of_finance__entities") }}
    where
        do_not_use = false
        and abolished = false
        and restricted_use is null
        and cast(primary_code as int) < 9000
        and not regexp_like(lower(name_raw), 'moved to|renum\.? to')
)

select
    *,
    1 as test_column
from active_entities

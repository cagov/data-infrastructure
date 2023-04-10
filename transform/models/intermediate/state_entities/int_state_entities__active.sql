{{ config(materialized="view") }}

with
    active_entities as (
        select *
        from {{ ref("stg_department_of_finance__entities") }}
        where
            do_not_use is false
            and abolished is false
            and restricted_use is null
            and cast(primary_code as int) < 9000
            and not regexp_contains(name_raw, r'(?i)Moved to|Renum\.? to')
    )

select *
from active_entities

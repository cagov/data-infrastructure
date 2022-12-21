{{ config(materialized="ephemeral") }}

with
    active_entities as (
        select *
        from {{ ref("stg_department_of_finance__entities") }}
        where do_not_use is false and abolished is false and restricted_use is null
    )

select *
from active_entities

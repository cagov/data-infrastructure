{{ config(materialized="table") }}

with
agencies as (
    select
        name,
        agency_code
    from {{ ref("int_state_entities__active") }}
    where subagency_code is null and l1 is null
)

select *
from agencies

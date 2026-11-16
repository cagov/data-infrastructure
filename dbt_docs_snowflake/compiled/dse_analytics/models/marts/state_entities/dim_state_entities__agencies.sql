

with
agencies as (
    select
        name,
        agency_code
    from TRANSFORM_DEV.ci_should_not_create_this_schema_state_entities.int_state_entities__active
    where subagency_code is null and l1 is null
)

select *
from agencies
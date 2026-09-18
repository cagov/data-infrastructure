





with validation_errors as (

    select
        A, B, L1, L2, L3
    from RAW_DEV.state_entities.base_entities
    group by A, B, L1, L2, L3
    having count(*) > 1

)

select *
from validation_errors



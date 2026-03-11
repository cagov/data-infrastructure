

with
technical_entities as (
    select *
    from TRANSFORM_DEV.ci_should_not_create_this_schema_department_of_finance.stg_department_of_finance__entities
    where
        (do_not_use = false and abolished = false)
        and (restricted_use is not null or cast(primary_code as int) >= 9000)
)

select *
from technical_entities
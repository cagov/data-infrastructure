





with validation_errors as (

    select
        organization_name, account_name, usage_date, service_type
    from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.int_credits_by_service_type
    group by organization_name, account_name, usage_date, service_type
    having count(*) > 1

)

select *
from validation_errors









with validation_errors as (

    select
        account_name, usage_date, usage_type
    from ANALYTICS_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.snowflake_costs_by_date
    group by account_name, usage_date, usage_type
    having count(*) > 1

)

select *
from validation_errors



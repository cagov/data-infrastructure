





with validation_errors as (

    select
        ORGANIZATION_NAME, ACCOUNT_NAME, USAGE_DATE
    from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.stg_metering_daily_history
    group by ORGANIZATION_NAME, ACCOUNT_NAME, USAGE_DATE
    having count(*) > 1

)

select *
from validation_errors




    
    



select CREDITS_USED_CLOUD_SERVICES
from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.stg_metering_daily_history
where CREDITS_USED_CLOUD_SERVICES is null



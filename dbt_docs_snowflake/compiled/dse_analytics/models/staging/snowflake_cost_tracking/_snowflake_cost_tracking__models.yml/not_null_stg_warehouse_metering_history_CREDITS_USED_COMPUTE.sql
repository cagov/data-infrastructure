
    
    



select CREDITS_USED_COMPUTE
from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.stg_warehouse_metering_history
where CREDITS_USED_COMPUTE is null




    
    



select AVERAGE_STAGE_BYTES
from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.stg_stage_storage_usage_history
where AVERAGE_STAGE_BYTES is null



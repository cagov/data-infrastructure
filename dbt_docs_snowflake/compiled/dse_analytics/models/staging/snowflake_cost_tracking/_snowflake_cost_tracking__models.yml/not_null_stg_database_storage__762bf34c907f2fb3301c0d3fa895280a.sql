
    
    



select AVERAGE_DATABASE_BYTES
from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.stg_database_storage_usage_history
where AVERAGE_DATABASE_BYTES is null



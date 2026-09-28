/*
Compute and cloud services credits, aggregated to account, usage date and service type.

Grouping of service types is provisional, Snowflake seems to update these fairly frequently.
*/

with source as (
    select * from {{ ref('stg_metering_daily_history_by_service_type') }}
),

usage_history as (
    select
        organization_name,
        account_name,
        usage_date,
        service_type,
        case
            -- Every flavour of Cortex / AI spend, which is billed under a surprising
            -- number of distinct service types.
            when service_type in (
                'AI_SERVICES',
                'AI_FUNCTIONS',
                'AI_INFERENCE',
                'CORTEX_SEARCH',
                'BATCH_CORTEX_SEARCH',
                'SNOWFLAKE_COCO_CLI',
                'SNOWFLAKE_COCO_DESKTOP',
                'SNOWFLAKE_COCO_SNOWSIGHT'
            ) then 'cortex'
            when service_type in ('WAREHOUSE_METERING', 'WAREHOUSE_METERING_READER')
                then 'warehouse'
            when service_type in ('SERVERLESS_TASK', 'SERVERLESS_ALERTS') then 'serverless'
            when service_type in ('TELEMETRY_DATA_INGEST', 'LOGGING') then 'observability'
            when service_type like 'OPENFLOW_COMPUTE%' then 'openflow'
            when service_type = 'SNOWPARK_CONTAINER_SERVICES' then 'container services'
            when service_type = 'TRUST_CENTER' then 'trust center'
            when service_type = 'AUTO_CLUSTERING' then 'automatic clustering'
            when service_type = 'MATERIALIZED_VIEW' then 'materialized view'
            when service_type = 'PIPE' then 'pipe'
            when service_type = 'SNOWPIPE_STREAMING' then 'snowpipe streaming'
            when service_type = 'QUERY_ACCELERATION' then 'query acceleration'
            when service_type = 'SEARCH_OPTIMIZATION' then 'search optimization'
            when service_type = 'REPLICATION' then 'replication'
            when service_type = 'COPY_FILES' then 'copy files'
            else 'other'
        end as usage_type,
        sum(credits_used) as credits_used
    from source
    group by all
)

select * from usage_history

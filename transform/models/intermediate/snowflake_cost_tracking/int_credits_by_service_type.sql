/*
Compute and cloud services credits, aggregated to account, usage date and service type.

This is the whole of `metering_daily_history` with nothing filtered out, which is what
makes `snowflake_costs_by_date` complete: service types Snowflake introduces later are
counted automatically, landing under the `other` usage type until someone gives them a
friendlier name. Storage is the one thing not covered, because `metering_daily_history`
measures compute and cloud services only.

History starts where `stg_metering_daily_history_by_service_type` starts, which is the
source view's retention boundary at the time that model was first built. Credits from
before then survive in `stg_metering_daily_history` and `stg_cortex_usage_daily_history`,
but only aggregated across service types, so they are deliberately left out of this
model rather than mixed in as an undifferentiated bucket. Those two staging models are
kept as archives for historical analysis.

The service type names below were taken from the data rather than from Snowflake's
documentation, which lists names this account does not use (`CORTEX_CODE_CLI`,
`CORTEX_CODE_SNOWSIGHT`) and omits several it does (`AI_FUNCTIONS`, `AI_INFERENCE`,
`SNOWFLAKE_COCO_*`, `CORTEX_SEARCH`). Re-check the `other` bucket periodically: a new
service type showing up there is the signal that this mapping needs extending.
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

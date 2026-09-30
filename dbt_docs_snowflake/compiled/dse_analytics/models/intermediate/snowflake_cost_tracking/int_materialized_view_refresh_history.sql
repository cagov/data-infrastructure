with source as (
    select * from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.stg_materialized_view_refresh_history
),

usage_history as (
    select
        organization_name,
        account_name,
        usage_date,
        sum(credits_used) as credits_used
    from source
    group by all
)

select * from usage_history
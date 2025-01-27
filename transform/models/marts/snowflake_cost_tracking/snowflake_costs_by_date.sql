with automatic_clustering_history as (
    select
        account_name,
        usage_date,
        'automatic clustering' as usage_type,
        credits_used
    from {{ ref('int_automatic_clustering_history') }}
),

materialized_view_refresh_history as (
    select
        account_name,
        usage_date,
        'materialized view' as usage_type,
        credits_used
    from {{ ref('int_materialized_view_refresh_history') }}
),

pipe_usage_history as (
    select
        account_name,
        usage_date,
        'pipe' as usage_type,
        credits_used
    from {{ ref('int_pipe_usage_history') }}
),

storage_daily_history as (
    select
        account_name,
        usage_date,
        'storage' as usage_type,
        credits_used
    from {{ ref('int_storage_daily_history') }}
),

warehouse_metering_history as (
    select
        account_name,
        usage_date,
        'warehouse' as usage_type,
        credits_used
    from {{ ref('int_warehouse_metering_history') }}
),

combined as (
    select * from automatic_clustering_history
    union all
    select * from materialized_view_refresh_history
    union all
    select * from pipe_usage_history
    union all
    select * from storage_daily_history
    union all
    select * from warehouse_metering_history
)

select * from combined

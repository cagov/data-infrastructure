with source as (
    select * from {{ ref('stg_cortex_usage_daily_history') }}
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

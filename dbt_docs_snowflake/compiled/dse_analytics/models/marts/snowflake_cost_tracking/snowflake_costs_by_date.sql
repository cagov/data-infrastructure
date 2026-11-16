/*
Snowflake credits consumed across the organization, by account, date and usage type.

There are exactly two sources, and between them they cover everything Snowflake bills
in credits:

  * `int_credits_by_service_type` — all compute and cloud services credits, taken whole
    from `metering_daily_history` with nothing filtered out.
  * `int_storage_daily_history` — storage, which `metering_daily_history` does not cover.

Keeping the union this small is deliberate. Earlier versions assembled the mart from one
model per feature, which meant coverage depended on remembering to add a model whenever
Snowflake introduced a new billable service, and query acceleration, search optimization
and replication were all missed that way.

Credits are rolled up to `usage_type`, a handful of friendly categories. The underlying
Snowflake `service_type` is finer grained and often cryptic, so it is left in
`int_credits_by_service_type` for anyone who needs to drill in.

Both sources are floored at the first date for which a service type breakdown exists.
*/

with credits_by_service_type as (
    select
        account_name,
        usage_date,
        usage_type,
        credits_used
    from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.int_credits_by_service_type
),

-- The earliest date with a service type breakdown. This is fixed rather than moving:
-- the staging model behind it is incremental and accumulates, so its earliest date
-- stays put once the model has been built.
first_date_with_service_type as (
    select min(usage_date) as usage_date
    from credits_by_service_type
),

storage_daily_history as (
    select
        storage.account_name,
        storage.usage_date,
        'storage' as usage_type,
        storage.credits_used
    from TRANSFORM_DEV.ci_should_not_create_this_schema_snowflake_cost_tracking.int_storage_daily_history as storage
    inner join first_date_with_service_type as earliest
        on storage.usage_date >= earliest.usage_date
),

combined as (
    select * from credits_by_service_type
    union all
    select * from storage_daily_history
),

-- Roll the several service types that share a usage type back up into one row, so the
-- grain is one row per account, date and usage type.
costs_by_date as (
    select
        account_name,
        usage_date,
        usage_type,
        sum(credits_used) as credits_used
    from combined
    group by all
)

select * from costs_by_date
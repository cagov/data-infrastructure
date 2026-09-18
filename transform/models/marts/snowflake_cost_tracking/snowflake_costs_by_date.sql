/*
Snowflake credits consumed across the organization, by account, date and service type.

There are exactly two members, and between them they cover everything Snowflake bills
in credits:

  * `int_credits_by_service_type` — all compute and cloud services credits, taken whole
    from `metering_daily_history` with nothing filtered out.
  * `int_storage_daily_history` — storage, which `metering_daily_history` does not cover.

Keeping the union this small is deliberate. Earlier versions assembled the mart from one
model per feature, which meant coverage depended on remembering to add a model whenever
Snowflake introduced a new billable service, and query acceleration, search optimization
and replication were all missed that way.

Both members are floored at the first date for which a service type breakdown exists.
Storage on its own reaches back further, but including that tail would show storage-only
days with no compute alongside them, which reads as a collapse in spend rather than as
absent data. Credits from before the floor are still held, aggregated across service
types, in `stg_metering_daily_history` and `stg_cortex_usage_daily_history`.
*/

with credits_by_service_type as (
    select
        organization_name,
        account_name,
        usage_date,
        service_type,
        usage_type,
        credits_used
    from {{ ref('int_credits_by_service_type') }}
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
        storage.organization_name,
        storage.account_name,
        storage.usage_date,
        'STORAGE' as service_type,
        'storage' as usage_type,
        storage.credits_used
    from {{ ref('int_storage_daily_history') }} as storage
    inner join first_date_with_service_type as earliest
        on storage.usage_date >= earliest.usage_date
),

-- Combine the data in long form to allow for easy
-- aggregations and visualizations.
combined as (
    select * from credits_by_service_type
    union all
    select * from storage_daily_history
)

select * from combined

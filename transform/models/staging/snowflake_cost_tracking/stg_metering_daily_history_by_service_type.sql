{{ config(
  materialized="incremental",
  unique_key=[
    "ORGANIZATION_NAME",
    "ACCOUNT_NAME",
    "USAGE_DATE",
    "SERVICE_TYPE",
    ],
  )
}}

-- Sibling of `stg_metering_daily_history`, which aggregates across service types.
-- The two are kept separate rather than adding SERVICE_TYPE to that model, because
-- its existing rows predate the column and would leave one table holding two grains.
-- This model therefore starts at the source view's retention boundary rather than at
-- the beginning of the older model's history.
WITH source AS (
    SELECT
        credits_adjustment_cloud_services,
        region,
        credits_used,
        service_type,
        account_locator,
        usage_date,
        account_name,
        credits_billed,
        credits_used_cloud_services,
        organization_name,
        credits_used_compute
    FROM {{ source('organization_usage', 'metering_daily_history') }}
),

metering_daily_history_by_service_type AS (
    SELECT
        organization_name,
        account_name,
        usage_date,
        service_type,
        sum(credits_used_compute) AS credits_used_compute,
        sum(credits_used_cloud_services) AS credits_used_cloud_services,
        sum(credits_adjustment_cloud_services) AS credits_adjustment_cloud_services,
        sum(credits_used) AS credits_used,
        sum(credits_billed) AS credits_billed
    FROM source
    GROUP BY ALL
)

SELECT *
FROM metering_daily_history_by_service_type

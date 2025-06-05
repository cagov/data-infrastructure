{{ config(
  materialized="incremental",
  unique_key=[
    "ORGANIZATION_NAME",
    "ACCOUNT_NAME",
    "USAGE_DATE",
    ],
  )
}}

-- The ORGANIZATION_USAGE schema does not provide a specific
-- view on Cortex usage, so we need to get it from the overall
-- metering daily history table.
-- https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql#track-costs-for-ai-services
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
    WHERE service_type = 'AI_SERVICES'
),

metering_daily_history AS (
    SELECT
        organization_name,
        account_name,
        usage_date,
        sum(credits_used_compute) AS credits_used_compute,
        sum(credits_used_cloud_services) AS credits_used_cloud_services,
        sum(credits_adjustment_cloud_services) AS credits_adjustment_cloud_services,
        sum(credits_used) AS credits_used,
        sum(credits_billed) AS credits_billed
    FROM source
    GROUP BY ALL
)

SELECT *
FROM metering_daily_history

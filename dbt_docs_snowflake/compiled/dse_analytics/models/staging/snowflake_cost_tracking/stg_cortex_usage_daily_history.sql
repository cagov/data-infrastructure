

-- Cortex usage derived from the overall metering daily history view.
--
-- This model is superseded by `stg_metering_daily_history_by_service_type`, which
-- breaks out every service type rather than just AI_SERVICES, and which shows that
-- Cortex is billed under several other service types this model never captured
-- (AI_FUNCTIONS, CORTEX_SEARCH, SNOWFLAKE_COCO_*, and more).
--
-- It is kept rather than dropped because it is an archive: it reaches back further
-- than the source view retains, so it holds the only surviving attribution of
-- AI_SERVICES spend for dates that have since aged out. Nothing downstream reads it;
-- it exists for historical analysis.
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
    FROM snowflake.organization_usage.metering_daily_history
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
    GROUP BY organization_name, account_name, usage_date
)

SELECT *
FROM metering_daily_history
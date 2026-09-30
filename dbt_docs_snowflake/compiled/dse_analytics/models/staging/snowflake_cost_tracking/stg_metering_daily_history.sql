

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
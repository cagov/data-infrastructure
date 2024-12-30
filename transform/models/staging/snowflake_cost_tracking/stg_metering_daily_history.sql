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

metering_daily_history AS (
    SELECT *
    FROM source
)

SELECT *
FROM metering_daily_history

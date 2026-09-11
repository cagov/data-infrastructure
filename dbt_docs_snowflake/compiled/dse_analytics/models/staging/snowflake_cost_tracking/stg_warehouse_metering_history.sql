

WITH source AS (
    SELECT
        account_name,
        warehouse_id,
        credits_used,
        credits_used_compute,
        region,
        start_time,
        credits_used_cloud_services,
        warehouse_name,
        organization_name,
        service_type,
        account_locator,
        end_time
    FROM snowflake.organization_usage.warehouse_metering_history
),

warehouse_metering_history AS (
    SELECT
        organization_name,
        account_name,
        warehouse_name,
        to_date(start_time) AS usage_date,
        sum(credits_used) AS credits_used,
        sum(credits_used_compute) AS credits_used_compute,
        sum(credits_used_cloud_services) AS credits_used_cloud_services
    FROM source
    GROUP BY ALL
)

SELECT *
FROM warehouse_metering_history
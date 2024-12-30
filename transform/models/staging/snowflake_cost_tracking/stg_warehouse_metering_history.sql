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
    FROM {{ source('organization_usage', 'warehouse_metering_history') }}
),

warehouse_metering_history AS (
    SELECT *
    FROM source
)

SELECT *
FROM warehouse_metering_history

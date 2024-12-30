WITH source AS (
    SELECT
        usage_date,
        organization_name,
        region,
        account_name,
        service_type,
        account_locator,
        average_bytes,
        credits
    FROM {{ source('organization_usage', 'storage_daily_history') }}
),

storage_daily_history AS (
    SELECT *
    FROM source
)

SELECT *
FROM storage_daily_history

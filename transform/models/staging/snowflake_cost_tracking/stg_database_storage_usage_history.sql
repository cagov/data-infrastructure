WITH source AS (
    SELECT
        region,
        average_hybrid_table_storage_bytes,
        organization_name,
        usage_date,
        database_id,
        database_name,
        account_name,
        average_database_bytes,
        account_locator,
        deleted,
        average_failsafe_bytes
    FROM {{ source('organization_usage', 'database_storage_usage_history') }}
),

database_storage_usage_history AS (
    SELECT *
    FROM source
)

SELECT *
FROM database_storage_usage_history

WITH source AS (
    SELECT
        organization_name,
        account_locator,
        account_name,
        region,
        usage_date,
        average_stage_bytes
    FROM {{ source('organization_usage', 'stage_storage_usage_history') }}
),

stage_storage_usage_history AS (
    SELECT *
    FROM source
)

SELECT *
FROM stage_storage_usage_history

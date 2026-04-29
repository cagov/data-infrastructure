

WITH source AS (
    SELECT
        organization_name,
        account_locator,
        account_name,
        region,
        usage_date,
        average_stage_bytes
    FROM snowflake.organization_usage.stage_storage_usage_history
),

stage_storage_usage_history AS (
    SELECT
        organization_name,
        account_name,
        usage_date,
        avg(average_stage_bytes) AS average_stage_bytes
    FROM source
    GROUP BY ALL
)

SELECT *
FROM stage_storage_usage_history
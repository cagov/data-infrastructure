WITH source AS (
    SELECT
        region,
        organization_name,
        bytes_inserted,
        files_inserted,
        usage_date,
        account_locator,
        credits_used,
        account_name,
        pipe_id,
        pipe_name
    FROM {{ source('organization_usage', 'pipe_usage_history') }}
),

pipe_usage_history AS (
    SELECT *
    FROM source
)

SELECT *
FROM pipe_usage_history

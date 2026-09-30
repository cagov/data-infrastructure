

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
    FROM snowflake.organization_usage.pipe_usage_history
),

pipe_usage_history AS (
    SELECT
        organization_name,
        account_name,
        pipe_name,
        usage_date,
        sum(bytes_inserted) AS bytes_inserted,
        sum(files_inserted) AS files_inserted,
        sum(credits_used) AS credits_used
    FROM source
    GROUP BY ALL
)

SELECT *
FROM pipe_usage_history
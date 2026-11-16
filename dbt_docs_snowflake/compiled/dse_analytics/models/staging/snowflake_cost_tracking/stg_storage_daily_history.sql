

WITH source AS (
    SELECT
        organization_name,
        account_name,
        account_locator,
        region,
        usage_date,
        service_type,
        average_bytes,
        credits
    FROM snowflake.organization_usage.storage_daily_history
),

storage_daily_history AS (
    SELECT
        organization_name,
        account_name,
        usage_date,
        avg(average_bytes) AS average_bytes,
        sum(credits) AS credits_used
    FROM source
    GROUP BY ALL
)

SELECT *
FROM storage_daily_history
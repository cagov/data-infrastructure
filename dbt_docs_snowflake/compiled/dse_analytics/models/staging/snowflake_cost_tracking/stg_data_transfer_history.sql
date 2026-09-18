

WITH source AS (
    SELECT
        organization_name,
        account_name,
        account_locator,
        region,
        usage_date,
        source_cloud,
        source_region,
        target_cloud,
        target_region,
        bytes_transferred,
        transfer_type
    FROM snowflake.organization_usage.data_transfer_history
),

data_transfer_history AS (
    SELECT
        organization_name,
        account_name,
        usage_date,
        source_cloud,
        source_region,
        target_cloud,
        target_region,
        sum(bytes_transferred) AS bytes_transferred
    FROM source
    GROUP BY ALL
)

SELECT *
FROM data_transfer_history


WITH source AS (
    SELECT
        num_rows_reclustered,
        account_locator,
        database_id,
        schema_name,
        database_name,
        table_id,
        schema_id,
        account_name,
        region,
        credits_used,
        organization_name,
        table_name,
        usage_date,
        num_bytes_reclustered
    FROM snowflake.organization_usage.automatic_clustering_history
),

automatic_clustering_history AS (
    SELECT
        organization_name,
        account_name,
        database_name,
        schema_name,
        table_name,
        usage_date,
        sum(credits_used) AS credits_used,
        sum(num_rows_reclustered) AS num_rows_reclustered,
        sum(num_bytes_reclustered) AS num_bytes_reclustered
    FROM source
    GROUP BY ALL
)

SELECT *
FROM automatic_clustering_history
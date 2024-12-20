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
    FROM {{ source('organization_usage', 'automatic_clustering_history') }}
),

automatic_clustering_history AS (
    SELECT *
    FROM source
)

SELECT *
FROM automatic_clustering_history

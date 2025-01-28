{{ config(
  materialized="incremental",
  unique_key=[
    "ORGANIZATION_NAME",
    "ACCOUNT_NAME",
    "DATABASE_NAME",
    "USAGE_DATE",
    ],
  )
}}

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
        average_failsafe_bytes
    FROM {{ source('organization_usage', 'database_storage_usage_history') }}
),

database_storage_usage_history AS (
    SELECT
        organization_name,
        account_name,
        database_name,
        usage_date,
        AVG(average_hybrid_table_storage_bytes) AS average_hybrid_table_storage_bytes,
        AVG(average_database_bytes) AS average_database_bytes,
        AVG(average_failsafe_bytes) AS average_failsafe_bytes
    FROM source
    GROUP BY ALL
)

SELECT *
FROM database_storage_usage_history

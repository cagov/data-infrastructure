{{ config(
  materialized="incremental",
  unique_key=[
    "ORGANIZATION_NAME",
    "ACCOUNT_NAME",
    "DATABASE_NAME",
    "SCHEMA_NAME",
    "TABLE_NAME",
    "USAGE_DATE",
    ],
  )
}}

WITH source AS (
    SELECT
        schema_name,
        credits_used,
        organization_name,
        database_id,
        schema_id,
        table_id,
        account_locator,
        account_name,
        region,
        database_name,
        table_name,
        usage_date
    FROM {{ source('organization_usage', 'materialized_view_refresh_history') }}
),

materialized_view_refresh_history AS (
    SELECT
        organization_name,
        account_name,
        database_name,
        schema_name,
        table_name,
        usage_date,
        sum(credits_used) AS credits_used
    FROM source
    GROUP BY ALL
)

SELECT *
FROM materialized_view_refresh_history

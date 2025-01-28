{{ config(
  materialized="incremental",
  unique_key=[
    "ORGANIZATION_NAME",
    "ACCOUNT_NAME",
    "USAGE_DATE",
    "SOURCE_CLOUD",
    "SOURCE_REGION",
    "TARGET_CLOUD",
    "TARGET_REGION",
    ],
  )
}}

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
    FROM {{ source('organization_usage', 'data_transfer_history') }}
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

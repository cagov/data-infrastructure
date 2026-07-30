"""
Minimal dlt testing pipeline for Azure SQL to Snowflake.
"""

import dlt
from dlt.sources.sql_database import sql_database


def load_tables_from_azure() -> None:
    # Define the pipeline
    pipeline = dlt.pipeline(
        pipeline_name="azure_sql_to_snowflake",
        destination="snowflake",
        dataset_name="dlt",  # maps to schema in snowflake, and will create if does not exist
    )

    # Fetch tables
    source = sql_database(table_names=["transactions", "users"])
    source.transactions.apply_hints(
        primary_key="id", incremental=dlt.sources.incremental("transaction_date")
    )
    source.users.apply_hints(
        primary_key="id", incremental=dlt.sources.incremental("created_at")
    )

    # Run the pipeline
    info = pipeline.run(source, write_disposition="merge")

    # Print load info
    print(info)


if __name__ == "__main__":
    load_tables_from_azure()

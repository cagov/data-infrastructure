from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake


def load_state_footprints(conn) -> None:
    """Load Microsoft state building footprints dataset for California."""
    import geopandas

    print("Downloading data")
    gdf = geopandas.read_file(
        "https://usbuildingdata.blob.core.windows.net/usbuildings-v2/Alaska.geojson.zip"
    )

    print("Writing data to snowflake")
    gdf_to_snowflake(
        gdf,
        conn,
        table_name="ALASKA_BUILDING_FOOTPRINTS",
        cluster=True,
    )


if __name__ == "__main__":
    import os

    import snowflake.connector

    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        schema="GEO_REFERENCE",
        role=os.environ["SNOWFLAKE_ROLE"],
    )
    load_state_footprints(conn)

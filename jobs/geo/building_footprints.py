from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake

SCHEMA = "GEO_REFERENCE"


def load_state_footprints(conn) -> None:
    """Load Microsoft state building footprints dataset for California."""
    import geopandas

    print("Downloading data")
    gdf = geopandas.read_file(
        "https://usbuildingdata.blob.core.windows.net/usbuildings-v2/Alaska.geojson.zip"
    )

    print("Writing data to gbq")
    gdf_to_snowflake(
        gdf,
        conn,
        table_name="ALASKA_BUILDING_FOOTPRINTS",
    )


if __name__ == "__main__":
    import os

    import snowflake.connector

    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["MY_SNOWFLAKE_PASSWORD"],
        warehouse="LOADING_DEV",
        database="RAW_DEV",
        schema="GEO_REFERENCE",
        role="LOADER_DEV",
    )
    load_state_footprints(conn)

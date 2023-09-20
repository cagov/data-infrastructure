from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_state_footprints(conn) -> None:
    """Load Microsoft state building footprints dataset for California."""
    import geopandas

    print("Downloading data")
    gdf = geopandas.read_file(
        "https://usbuildingdata.blob.core.windows.net/usbuildings-v2/California.geojson.zip"
    )

    print("Writing data to snowflake")
    gdf_to_snowflake(
        gdf,
        conn,
        table_name="US_BUILDING_FOOTPRINTS",
        cluster=False,
    )


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="BUILDING_FOOTPRINTS",
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )
    load_state_footprints(conn)

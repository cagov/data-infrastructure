from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_state_footprints(conn) -> None:
    """Load California county data."""
    import geopandas
    import requests

    print("Downloading data")
    geojson = "https://gis.data.ca.gov/datasets/CALFIRE-Forestry::california-county-boundaries.geojson"
    r = requests.Request("GET", geojson).prepare()
    session = requests.Session()
    response = session.send(r)
    gdf = geopandas.GeoDataFrame.from_features(response.json(), crs="ESRI:102100")

    print("Writing data to snowflake")
    gdf_to_snowflake(
        gdf,
        conn,
        table_name="CALIFORNIA_COUNTIES",
        cluster=False,
    )


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        warehouse="LOADING_DEV",
        database="RAW_DEV",
        schema="GEO_REFERENCE",
        role="LOADER_DEV",
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )
    load_state_footprints(conn)

from __future__ import annotations

from io import StringIO

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_geo_data(conn, url: str, table: str) -> None:
    """Load general geospatial data. Given a URL, load geospatial data into Snowflake."""
    import geopandas
    import requests

    print(f"Downloading data {table} from {url}")

    # Some of the target sources come from Esri servers, and GDAL's vsi system
    # can be cranky about reading from them (issues with range requests and other
    # weird errors). So instead we load the data first into a text blob using
    # requests, then hand it off to geopandas.
    f = StringIO(requests.get(url).text)
    gdf = geopandas.read_file(f)

    print(f"Writing {table} to snowflake")
    gdf_to_snowflake(
        gdf,
        conn,
        table_name=table,
        cluster=False,
    )


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        warehouse="LOADING_DEV",
        database="RAW_DEV",
        schema="GEO_REFERENCE",
        role="LOADER_DEV",
        client_session_keep_alive=True,
    )

    import sys

    # TODO: perhaps make a real CLI here.
    N_ARGS = 3
    assert (
        len(sys.argv) == N_ARGS
    ), "Expecting exactly two arguments: URL and table name."
    load_geo_data(conn, sys.argv[1], sys.argv[2])

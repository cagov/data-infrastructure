from __future__ import annotations

from io import StringIO

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_city_county_data(conn, url: str, table: str) -> None:
    """Load California county data. Given a URL, load geospatial data into BigQuery."""
    import geopandas
    import requests

    print("Downloading data")

    f = StringIO(requests.get(url).text)
    gdf = geopandas.read_file(f)

    print("Writing data to snowflake")
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
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )

    import sys

    # TODO: perhaps make a real CLI here.
    N_ARGS = 3
    assert (
        len(sys.argv) == N_ARGS
    ), "Expecting exactly two arguments: URL and table name."
    load_city_county_data(conn, sys.argv[1], sys.argv[2])

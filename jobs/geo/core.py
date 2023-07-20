from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_geo_data(conn, state: str, year: str, table: str) -> None:
    """Load general geospatial data. Given a URL, load geospatial data into Snowflake."""
    from pygris import counties

    print(f"Downloading data {table} for {state} in year {year}")

    # Some of the target sources come from Esri servers, and GDAL's vsi system
    # can be cranky about reading from them (issues with range requests and other
    # weird errors). So instead we load the data first into a text blob using
    # requests, then hand it off to geopandas.

    c = counties(state=state, year=year, cache=True)

    print(f"Writing {table} to snowflake")
    gdf_to_snowflake(
        c,
        conn,
        table_name=table,
        cluster=False,
    )


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="GEO_REFERENCE",
        client_session_keep_alive=True,
    )

    import sys

    # TODO: perhaps make a real CLI here.
    N_ARGS = 4
    assert (
        len(sys.argv) == N_ARGS
    ), "Expecting exactly 3 arguments: two letter state abbreviation, four digit year, and table name."
    load_geo_data(conn, sys.argv[1], sys.argv[2], sys.argv[3])

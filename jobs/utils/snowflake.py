"""Snowflake utilities."""
from __future__ import annotations

import random
import string
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import geopandas
    import snowflake.connector

WGS84 = 4326  # EPSG for geography


def gdf_to_snowflake(
    gdf: geopandas.GeoDataFrame,
    conn: snowflake.connector.SnowflakeConnection,
    table_name: str,
    *,
    database: str | None = None,
    schema: str | None = None,
    auto_create_table: bool = True,
    cluster: bool | str = False,
):
    import geopandas
    from snowflake.connector.pandas_tools import write_pandas

    tmp = "".join(random.choices(string.ascii_uppercase, k=3))
    tmp_table = f"{table_name}_TMP_{tmp}"

    database = database or conn.database
    schema = schema or conn.schema

    if not database:
        raise ValueError("Must supply a database name")
    if not schema:
        raise ValueError("Must supply a schema name")

    try:
        if not gdf.crs:
            raise ValueError("Must supply a GeoDataFrame with a known CRS")

        epsg = gdf.crs.to_epsg()

        conn.cursor().execute(f"CREATE SCHEMA IF NOT EXISTS {database}.{schema}")
        write_pandas(
            conn,
            gdf.to_wkb(),
            table_name=tmp_table,
            table_type="temp",
            database=database,
            schema=schema,
            auto_create_table=auto_create_table,
            quote_identifiers=True,
        )

        cols = []
        for c, dtype in gdf.dtypes.to_dict().items():
            if type(dtype) == geopandas.array.GeometryDtype:
                if epsg == WGS84:
                    cols.append(f'TO_GEOGRAPHY("{c}") AS "{c}"')
                else:
                    cols.append(f'TO_GEOMETRY("{c}", {epsg}) AS "{c}"')
            else:
                cols.append(f'"{c}"')

        conn.cursor().execute(
            f"""
CREATE OR REPLACE TABLE {database}.{schema}.{table_name} AS (
    SELECT {",".join(cols)} FROM {database}.{schema}.{tmp_table}
)"""
        )
    finally:
        conn.cursor().execute(f"DROP TABLE IF EXISTS {database}.{schema}.{tmp_table}")

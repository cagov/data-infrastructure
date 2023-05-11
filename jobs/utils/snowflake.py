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
    cluster: bool | str = False,
):
    """
    Load a GeoDataFrame to Snowflake.

    If the table and schema don't exist, this creates them.
    ``cluster`` can be a boolean, string, or list of strings,
    and sets clustering keys for the resulting table.
    """
    import geopandas
    import shapely
    from snowflake.connector.pandas_tools import write_pandas

    # Database and schema might be set on the connection object
    database = database or conn.database
    schema = schema or conn.schema

    if not database:
        raise ValueError("Must supply a database name")
    if not schema:
        raise ValueError("Must supply a schema name")

    # Create the initial table as a tmp table with a random suffix.
    # We will drop it at the end.
    tmp = "".join(random.choices(string.ascii_uppercase, k=3))
    tmp_table = f"{table_name}_TMP_{tmp}"

    try:
        if not gdf.crs:
            raise ValueError("Must supply a GeoDataFrame with a known CRS")

        # Ensure that the geometry columns are properly oriented and valid geometries.
        gdf = gdf.assign(
            **{
                name: gdf[name].make_valid().apply(shapely.ops.orient, args=(1,))
                for name, dtype in gdf.dtypes.items()
                if isinstance(dtype, geopandas.array.GeometryDtype)
            }
        )  # type: ignore

        epsg = gdf.crs.to_epsg()

        # Ensure cluster names are a list and properly quoted
        cluster_names = []
        if cluster is True:
            cluster_names = [gdf.geometry.name]
        elif isinstance(cluster, str):
            cluster_names = [cluster]
        cluster_names = [f'"{n}"' for n in cluster_names]

        # Write the initial table with the geometry columns as bytes. We can convert to
        # geography or geometry later. This is one more step than I would like, but the
        # write_pandas utility has some nice features that I don't want to reimplement,
        # like chunked uploading to stages as parquet.
        conn.cursor().execute(f"CREATE SCHEMA IF NOT EXISTS {database}.{schema}")
        write_pandas(
            conn,
            gdf.to_wkb(),
            table_name=tmp_table,
            table_type="temp",
            database=database,
            schema=schema,
            auto_create_table=True,
            quote_identifiers=True,
        )

        # Identify the geometry columns so we can cast them to the appropriate type
        cols = []
        for c, dtype in gdf.dtypes.to_dict().items():
            if type(dtype) == geopandas.array.GeometryDtype:
                if epsg == WGS84:
                    cols.append(f'TO_GEOGRAPHY("{c}") AS "{c}"')
                else:
                    cols.append(f'TO_GEOMETRY("{c}", {epsg}) AS "{c}"')
            else:
                cols.append(f'"{c}"')

        sql = f"""CREATE OR REPLACE TABLE {database}.{schema}.{table_name}"""

        if cluster:
            sql = sql + f"\nCLUSTER BY ({','.join(cluster_names)})"

        sql = (
            sql
            + f"""\nAS SELECT \n{",".join(cols)} \nFROM {database}.{schema}.{tmp_table}"""
        )
        print(sql)

        conn.cursor().execute(sql)
    finally:
        conn.cursor().execute(f"DROP TABLE IF EXISTS {database}.{schema}.{tmp_table}")

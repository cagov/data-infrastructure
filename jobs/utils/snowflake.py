"""Snowflake utilities."""
from __future__ import annotations

import os
import random
import string
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import geopandas
    import snowflake.connector

WGS84 = 4326  # EPSG for geography


def snowflake_connection_from_environment(**kwargs):
    """
    Create a Snowflake Connection object based on environment variables.

    The following are required to be set:

        SNOWFLAKE_ACCOUNT
        SNOWFLAKE_USER

    You must supply exactly one authentication mechanism of the following:

        SNOWFLAKE_PASSWORD
        SNOWFLAKE_PRIVATE_KEY
        SNOWFLAKE_PRIVATE_KEY_PATH

    If using private key authentication and it is encrypted, you must supply

        SNOWFLAKE_PRIVATE_KEY_PASSPHRASE

    Other parameters which may be a good idea to set in environment variables are:

        SNOWFLAKE_ROLE
        SNOWFLAKE_WAREHOUSE
        SNOWFLAKE_DATABASE
        SNOWFLAKE_SCHEMA

    Keyword args are passed on to ``snowflake.connector.connect``.
    """
    import snowflake.connector

    # Required parameters
    account = os.environ["SNOWFLAKE_ACCOUNT"]
    user = os.environ["SNOWFLAKE_USER"]

    # Optional parameters
    warehouse = os.environ.get("SNOWFLAKE_WAREHOUSE")
    database = os.environ.get("SNOWFLAKE_DATABASE")
    schema = os.environ.get("SNOWFLAKE_SCHEMA")
    role = os.environ.get("SNOWFLAKE_ROLE")

    # Sensitive stuff
    password = os.environ.get("SNOWFLAKE_PASSWORD")
    private_key: str | None = os.environ.get("SNOWFLAKE_PRIVATE_KEY")
    private_key_path = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH")
    private_key_passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE")

    parameters = {
        "account": account,
        "user": user,
        "warehouse": warehouse,
        "database": database,
        "schema": schema,
        "role": role,
    }

    # Check that there is only one authentication mechanism implied between
    # password, private key, and private key path.
    if sum([bool(password), bool(private_key), bool(private_key_path)]) != 1:
        raise ValueError(
            "Must set exactly one of SNOWFLAKE_PASSWORD, SNOWFLAKE_PRIVATE_KEY, or"
            "SNOWFLAKE_PRIVATE_KEY_PATH"
        )

    if password:
        parameters["password"] = password
    else:
        # Based on https://community.snowflake.com/s/article/How-To-Connect-to-Snowflake
        # -using-key-pair-authentication-directly-using-the-private-key-incode-with-the-
        # Python-Connector
        from cryptography.hazmat.backends import default_backend
        from cryptography.hazmat.primitives import serialization

        if private_key_path:
            with open(private_key_path) as keyfile:
                private_key = keyfile.read()
        assert private_key
        p_key = serialization.load_pem_private_key(
            private_key.encode(),
            password=private_key_passphrase.encode()
            if private_key_passphrase
            else None,
            backend=default_backend(),
        )

        pkb = p_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        )
        parameters["private_key"] = pkb

    # Apply user overrides
    parameters.update(kwargs)

    return snowflake.connector.connect(**parameters)


def gdf_to_snowflake(
    gdf: geopandas.GeoDataFrame,
    conn: snowflake.connector.SnowflakeConnection,
    table_name: str,
    *,
    database: str | None = None,
    schema: str | None = None,
    cluster: bool | str = False,
    chunk_size: int | None = None,
    overwrite: bool = True,
):
    """
    Load a GeoDataFrame to Snowflake.

    If the table and schema don't exist, this creates them.
    ``cluster`` can be a boolean, string, or list of strings,
    and sets clustering keys for the resulting table.
    """
    import geopandas.array
    import shapely.ops
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
        if any(
            isinstance(gdf[n].dtype, geopandas.array.GeometryDtype)
            for n in cluster_names
        ):
            raise ValueError(
                "Snowflake does not support clustering on geospatial types"
            )
        cluster_names = [f'"{n}"' for n in cluster_names]

        # Write the initial table with the geometry columns as bytes. We can convert to
        # geography or geometry later. This is one more step than I would like, but the
        # write_pandas utility has some nice features that I don't want to reimplement,
        # like chunked uploading to stages as parquet.
        conn.cursor().execute(f'CREATE SCHEMA IF NOT EXISTS "{database}"."{schema}"')
        write_pandas(
            conn,
            gdf.to_wkb(),
            table_name=tmp_table,
            table_type="temp",
            database=database,
            schema=schema,
            chunk_size=chunk_size,
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

        if overwrite:
            # Create the final table, selecting from the temp table.
            sql = f'''CREATE OR REPLACE TABLE "{database}"."{schema}"."{table_name}"'''
            if cluster:
                sql = sql + f"\nCLUSTER BY ({','.join(cluster_names)})"
            sql = (
                sql
                + f'''\nAS SELECT \n{",".join(cols)} \nFROM "{database}"."{schema}"."{tmp_table}"'''
            )
        else:
            if cluster:
                raise ValueError(
                    "Clustering on existing table (overwrite=False) not supported"
                )
            sql = (
                f'''INSERT INTO "{database}"."{schema}"."{table_name}"'''
                f'''\nSELECT \n{",".join(cols)} \nFROM "{database}"."{schema}"."{tmp_table}"'''
            )

        conn.cursor().execute(sql)
    finally:
        conn.cursor().execute(
            f'DROP TABLE IF EXISTS "{database}"."{schema}"."{tmp_table}"'
        )

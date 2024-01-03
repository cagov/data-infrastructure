from __future__ import annotations

import os

from jobs.utils.snowflake import snowflake_connection_from_environment


def write_building_footprints(conn, kind: str):
    """Grab Microsoft building footprints data enriched with Census TIGER Blocks data for California from Snowflake and write to an S3 bucket."""
    import geopandas
    import s3fs
    import shapely.wkb

    sql_alter = """
    alter session set GEOGRAPHY_OUTPUT_FORMAT='WKB';
    """
    conn.cursor().execute(sql_alter)

    ref = (
        "ANALYTICS_PRD.BUILDING_FOOTPRINTS"
        f".GEO_REFERENCE__{kind.upper()}_BUILDING_FOOTPRINTS_WITH_TIGER"
    )
    sql_counties = f"""
    SELECT DISTINCT "county_fips"
    FROM {ref}
    ORDER BY 1 ASC
    """

    counties = conn.cursor().execute(sql_counties).fetchall()
    counties = [x[0] for x in counties if x[0] is not None]

    for index, county in enumerate(counties):
        sql_table = f"""
        SELECT *
        FROM {ref}
        WHERE "county_fips" = {county}
        """
        df = conn.cursor().execute(sql_table).fetch_pandas_all()
        gdf = geopandas.GeoDataFrame(
            df.assign(geometry=df.geometry.apply(shapely.wkb.loads)),
            crs="EPSG:4326",
        )

        gdf = gdf[gdf.geometry.geom_type != "GeometryCollection"]

        file_prefix = f"county_fips_{county}"
        gdf.to_parquet(f"{file_prefix}.parquet")
        # .shz suffix triggers GDAL to write zipped shapefile
        gdf.to_file(f"{file_prefix}.shz")

        print(
            f"Loading {file_prefix}. This is number {index+1} out of {len(counties)} counties."
        )

        s3 = s3fs.S3FileSystem(anon=False)
        s3.put(
            f"{file_prefix}.parquet",
            f"s3://dof-demographics-dev-us-west-2-public/{kind}_building_footprints/parquet/{file_prefix}.parquet",
        )
        # Esri doesn't like .shp.zip or .shz, so rename to just be .zip.
        s3.put(
            f"{file_prefix}.shz",
            f"s3://dof-demographics-dev-us-west-2-public/{kind}_building_footprints/shp/{file_prefix}.zip",
        )

        os.remove(f"{file_prefix}.parquet")
        os.remove(f"{file_prefix}.shz")


if __name__ == "__main__":
    import sys

    N_ARGS = 1

    # This is a bit of a hack: our batch jobs are designed more around loading data
    # to a data warehouse than unloading it, and so the default connection parameters
    # specify a LOADER role. Here we replace that with a REPORTER role for grabbing
    # data from the marts db.
    os.environ["SNOWFLAKE_ROLE"] = os.environ["SNOWFLAKE_ROLE"].replace(
        "LOADER", "REPORTER"
    )
    os.environ["SNOWFLAKE_WAREHOUSE"] = os.environ["SNOWFLAKE_WAREHOUSE"].replace(
        "LOADING", "REPORTING"
    )

    conn = snowflake_connection_from_environment(
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )

    if len(sys.argv) != N_ARGS + 1 or sys.argv[1] not in ("global_ml", "us"):
        raise ValueError(
            "Must provide specify one of 'global_ml' or 'us' for building footprint source"
        )

    write_building_footprints(conn, kind=sys.argv[1])

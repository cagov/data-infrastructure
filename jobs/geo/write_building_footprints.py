from __future__ import annotations

from jobs.utils.snowflake import snowflake_connection_from_environment


def write_building_footprints(conn):
    """Grab Microsoft building footprints data enriched with Census TIGER Blocks data for California from Snowflake and write to an S3 bucket."""
    import os

    import geopandas
    import s3fs
    import shapely

    sql_alter = """
    alter session set GEOGRAPHY_OUTPUT_FORMAT='WKB';
    """
    conn.cursor().execute(sql_alter)

    counties = """
    SELECT DISTINCT "county_fips"
    FROM ANALYTICS_DEV.ANALYTICS.GEO_REFERENCE__BUILDING_FOOTPRINTS_WITH_TIGER
    ORDER BY 1 ASC
    """

    counties = conn.cursor().execute(counties).fetchall()
    counties = [x[0] for x in counties if x[0] is not None]

    for index, county in enumerate(counties):
        sql_table = f"""
        SELECT *
        FROM ANALYTICS_DEV.ANALYTICS.GEO_REFERENCE__BUILDING_FOOTPRINTS_WITH_TIGER
        WHERE "county_fips" = {county}
        """
        df = conn.cursor().execute(sql_table).fetch_pandas_all()
        gdf = geopandas.GeoDataFrame(
            df.assign(geometry=df.geometry.apply(shapely.wkb.loads))
        )

        gdf = gdf[gdf.geometry.geom_type != "GeometryCollection"]

        file_prefix = f"footprints_with_tiger_for_county_fips_{county}"
        gdf.to_parquet(f"{file_prefix}.parquet")
        gdf.to_file(f"{file_prefix}.shp.zip")

        print(
            f"Loading {file_prefix}. This is number {index+1} out of {len(counties)} counties."
        )

        s3 = s3fs.S3FileSystem(anon=False)
        s3.put(
            f"{file_prefix}.parquet",
            "s3://dof-demographics-dev-us-west-2-public/parquet/",
        )
        s3.put(
            f"{file_prefix}.shp.zip", "s3://dof-demographics-dev-us-west-2-public/shp/"
        )

        os.remove(f"{file_prefix}.parquet")
        os.remove(f"{file_prefix}.shp.zip")


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="GEO_REFERENCE",
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )
    write_building_footprints(conn)

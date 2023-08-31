from __future__ import annotations

import s3fs

from jobs.utils.snowflake import snowflake_connection_from_environment


def write_building_footprints(conn):
    """Grab Microsoft state building footprint data for California from Snowflake and write to an S3 bucket."""
    import geopandas
    import shapely

    sql_alter = """
    alter session set GEOGRAPHY_OUTPUT_FORMAT='WKB';
    """
    conn.cursor().execute(sql_alter)

    counties = """
    SELECT DISTINCT "county_fips"
    FROM ANALYTICS_DEV.ANALYTICS.GEO_REFERENCE__BUILDING_FOOTPRINTS_WITH_BLOCKS
    """

    counties = conn.cursor().execute(counties).fetchall()
    counties = [x[0] for x in counties if x[0] is not None]

    for county in counties:
        sql_table = f"""
        SELECT *
        FROM ANALYTICS_DEV.ANALYTICS.GEO_REFERENCE__BUILDING_FOOTPRINTS_WITH_BLOCKS
        WHERE "county_fips" = {county}
        """
        df = conn.cursor().execute(sql_table).fetch_pandas_all()
        gdf = geopandas.GeoDataFrame(
            df.assign(geometry=df.geometry.apply(shapely.wkb.loads))
        )
        gdf.to_parquet(f"footprints_with_blocks_for_county_fips_{county}.parquet")
        gdf.to_file(
            f"footprints_with_blocks_for_county_fips_{county}.shp.zip",
            driver="ESRI Shapefile",
        )
        print(f"loading footprints_with_blocks_for_county_fips_{county}")

        s3 = s3fs.S3FileSystem(anon=False)
        s3.put(
            f"footprints_with_blocks_for_county_fips_{county}.parquet",
            "dof-demographics-dev-us-west-2-public/",
            recursive=True,
        )
        s3.put(
            f"footprints_with_blocks_for_county_fips_{county}.shp.zip",
            "dof-demographics-dev-us-west-2-public/",
            recursive=True,
        )


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="GEO_REFERENCE",
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )
    write_building_footprints(conn)

from __future__ import annotations

from jobs.utils.snowflake import snowflake_connection_from_environment


def write_building_footprints(conn):
    """Grab Microsoft state building footprint data for California from Snowflake and write to an S3 bucket."""
    import geopandas
    import shapely

    sql_transform = """
    alter session set GEOGRAPHY_OUTPUT_FORMAT='WKB';
    """
    conn.cursor().execute(sql_transform)

    sql_table = """
    SELECT *
    FROM ANALYTICS_DEV.ANALYTICS.GEO_REFERENCE__BUILDING_FOOTPRINTS_WITH_BLOCKS
    """

    df = conn.cursor().execute(sql_table).fetch_pandas_all()
    gdf = geopandas.GeoDataFrame(
        df.assign(geometry=df.geometry.apply(shapely.wkb.loads))
    )

    # write parquet and shape files for every single county locally

    counties = gdf.county_fips.unique()

    for x in counties:
        gdf[gdf.county_fips == x].to_parquet(f"test_{x}.parquet")
        gdf[gdf.county_fips == x].to_file(
            f"test_{x}.shp"
        )  # this currently outputs .cpg, .dbf, .shx files in addition to .shp, not sure if that is intended


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="GEO_REFERENCE",
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )
    write_building_footprints(conn)

from __future__ import annotations

import logging
import os

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment

for logger_name in ("snowflake.connector",):
    logger = logging.getLogger(logger_name)
    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(
        logging.Formatter(
            "%(asctime)s - %(threadName)s %(filename)s:%(lineno)d - %(funcName)s() - %(levelname)s - %(message)s"
        )
    )
    logger.addHandler(ch)


HERE = os.path.dirname(os.path.abspath(__file__))


def load_state_footprints(conn) -> None:
    """Load Microsoft Global ML building footprints dataset for California."""
    import fsspec
    import geopandas
    import mercantile
    import pandas
    import shapely.geometry

    print("Identifying California quadkeys")
    df = pandas.read_csv(
        "https://minedbuildings.blob.core.windows.net/global-buildings/dataset-links.csv",
        dtype={"QuadKey": "str"},  # Don't use an int, since there are leading zeros!
    )

    # Get the shape of California so that we can identify the quadkeys which intersect
    california = (
        geopandas.read_file(os.path.join(HERE, "data", "california.geojson"))
        .iloc[0]
        .geometry
    )

    # As a first pass, find all the tiles which intersect the bounding box,
    # since that's what mercantile knows how to do.
    features = []
    for tile in mercantile.tiles(*california.bounds, zooms=9):
        features.append(
            {
                "quadkey": mercantile.quadkey(tile),
                "geometry": shapely.geometry.shape(
                    mercantile.feature(tile)["geometry"]
                ),
            }
        )

    # As a second pass, prune out the tiles which don't actually intersect California
    quadkeys = geopandas.GeoDataFrame.from_records(features)
    california_quadkeys = quadkeys[quadkeys.intersects(california)]

    # Now get a list of all the URLs which have a quadkey intersecting California
    california_data = df[
        df.QuadKey.isin(california_quadkeys.quadkey) & (df.Location == "UnitedStates")
    ]

    overwrite = True  # For the first subset, overwrite any existing table
    for _, row in california_data.iterrows():
        print(f"Reading quadkey {row.QuadKey}")
        with fsspec.open(row.Url, compression="infer") as f:
            gdf = geopandas.read_file(f, driver="GeoJSONSeq")
        # If we include quadkeys here it could help with Snowflake partitioning
        gdf = gdf.assign(quadkey=row.QuadKey)
        gdf_to_snowflake(
            gdf,
            conn,
            table_name="GLOBAL_ML_BUILDING_FOOTPRINTS",
            overwrite=overwrite,
            strict_geometries=False,
        )
        overwrite = False  # For all subsequent gdfs, append


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="BUILDING_FOOTPRINTS",
        client_session_keep_alive=True,  # This can be a slow job! Keep the session alive
    )
    load_state_footprints(conn)

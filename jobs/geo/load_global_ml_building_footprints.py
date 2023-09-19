from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_state_footprints(conn) -> None:
    """Load Microsoft Global ML building footprints dataset for California."""
    import geopandas
    import mercantile
    import pandas
    import shapely.geometry

    print("Identifying California quadkeys")
    df = pandas.read_csv(
        "https://minedbuildings.blob.core.windows.net/global-buildings/dataset-links.csv",
        dtype={"QuadKey": "str"},  # Don't use an int, since there are leading zeros!
    )

    # TODO: use better source, perhaps the TIGER source, or include a california geojson in the repo
    states = geopandas.read_file(
        "https://github.com/PublicaMundi/MappingAPI/raw/master/data/geojson/us-states.json"
    )
    california = states[states.id == "06"].iloc[0].geometry

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

    quadkeys = geopandas.GeoDataFrame.from_records(features)
    california_quadkeys = quadkeys[quadkeys.intersects(california)]

    california_data = df[
        df.QuadKey.isin(california_quadkeys.quadkey) & (df.Location == "UnitedStates")
    ]
    overwrite = True  # For the first subset, overwrite any existing table
    for _, row in california_data.iterrows():
        print(f"Reading quadkey {row.QuadKey}")
        gdf = geopandas.GeoDataFrame(
            pandas.read_json(row.Url, lines=True).assign(
                geometry=lambda df: df.geometry.apply(shapely.geometry.shape),
                quadkey=row.QuadKey,  # Note, if we include quadkeys here it could help with Snowflake partitioning
            ),
            crs="EPSG:4326",
        )
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

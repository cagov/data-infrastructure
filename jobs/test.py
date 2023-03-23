from __future__ import annotations

import os

import geopandas

URL = "https://usbuildingdata.blob.core.windows.net/usbuildings-v2/Alaska.geojson.zip"

if __name__ == "__main__":
    gdf = geopandas.read_file(URL)
    gdf.to_parquet(f"s3://{os.environ['BUCKET']}/alaska.parquet")

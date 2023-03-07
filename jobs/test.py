from __future__ import annotations
import geopandas

URL = "https://usbuildingdata.blob.core.windows.net/usbuildings-v2/Alaska.geojson.zip"

if __name__ == "__main__":
    gdf = geopandas.read_file(URL)
    gdf.to_parquet("s3://dse-infra-dev-scratch/alaska.parquet")

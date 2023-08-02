from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_geo_data(conn, year: int) -> None:
    """Load CA Census geo data into Snowflake."""
    from fiona.errors import DriverError
    from pygris import (
        block_groups,
        blocks,
        coastline,
        combined_statistical_areas,
        core_based_statistical_areas,
        counties,
        county_subdivisions,
        divisions,
        nation,
        native_areas,
        places,
        primary_roads,
        primary_secondary_roads,
        pumas,
        rails,
        regions,
        states,
        tracts,
        tribal_block_groups,
        tribal_subdivisions_national,
        urban_areas,
    )

    print(f"Downloading data for CA in year {year}")

    ca_loaders = {
        "COUNTIES": counties,
        "TRACTS": tracts,
        "BLOCK_GROUPS": block_groups,
        "BLOCKS": blocks,
        "PLACES": places,
        "PUMAS": pumas,
        "COUNTY_SUBDIVISIONS": county_subdivisions,
        "PRIMARY_SECONDARY_ROADS": primary_secondary_roads,
    }

    us_loaders = {
        "COASTLINE": coastline,
        "DIVISIONS": divisions,
        "NATION": nation,
        "NATIVE_AREAS": native_areas,
        "PRIMARY_ROADS": primary_roads,
        "RAILS": rails,
        "REGIONS": regions,
        "STATES": states,
        "TRIBAL_BLOCK_GROUPS": tribal_block_groups,
        "TRIBAL_SUBDIVISIONS_NATIONAL": tribal_subdivisions_national,
        "URBAN_AREAS": urban_areas,
        "CORE_BASED_STATISTICAL_AREAS": core_based_statistical_areas,
        "COMBINED_STATISTICAL_AREAS": combined_statistical_areas,
    }

    state = "CA"

    for table_name, loader in ca_loaders.items():
        try:
            gdf_to_snowflake(
                loader(state=state, year=year)
                .reset_index(drop=True)
                .to_crs(
                    epsg=4326
                ),  # using .reset_index(drop=True) to address the following UserWarning:
                # Pandas Dataframe has non-standard index of type <class 'pandas.core.indexes.base.Index'> which will not be written. Consider changing the
                # index to pd.RangeIndex(start=0,...,step=1) or call reset_index() to keep index as column(s)
                conn,
                table_name=table_name,
                cluster=False,
            )
        except ValueError as value_error:
            print(
                f"This ValueError: {value_error} This pertains to this CA loader: {table_name}"
            )
            continue

        except DriverError as driver_error:
            print(
                f"This DriverError: {driver_error} This pertains to this CA loader: {table_name}"
            )
            continue

    for table_name, loader in us_loaders.items():
        try:
            gdf_to_snowflake(
                loader(year=year)
                .reset_index(drop=True)
                .to_crs(
                    epsg=4326
                ),  # using .reset_index(drop=True) to address the following UserWarning:
                # Pandas Dataframe has non-standard index of type <class 'pandas.core.indexes.base.Index'> which will not be written. Consider changing the
                # index to pd.RangeIndex(start=0,...,step=1) or call reset_index() to keep index as column(s)
                conn,
                table_name=table_name,
                cluster=False,
            )
        except ValueError as value_error:
            print(
                f"This ValueError: {value_error} This pertains to this US loader: {table_name}"
            )
            continue

        except DriverError as driver_error:
            print(
                f"This DriverError: {driver_error} This pertains to this US loader: {table_name}"
            )
            continue


if __name__ == "__main__":
    # TODO: perhaps make a real CLI here.
    import sys

    N_ARGS = 2
    assert len(sys.argv) == N_ARGS, "Expecting 1 argument: year (four digits)"

    year = int(sys.argv[1])

    conn = snowflake_connection_from_environment(
        schema=f"TIGER_{year}",
        client_session_keep_alive=True,
    )

    load_geo_data(conn, year)

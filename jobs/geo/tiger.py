from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_geo_data(conn, year: str) -> None:
    """Load CA Census geo data into Snowflake."""
    from pygris import (
        block_groups,
        blocks,
        counties,
        county_subdivisions,
        places,
        primary_secondary_roads,
        pumas,
        tracts,
        coastline,
        divisions,
        nation,
        native_areas,
        primary_roads,
        rails,
        regions,
        states,
        tribal_block_groups,
        tribal_subdivisions_national,
        urban_areas,
        core_based_statistical_areas, 
        combined_statistical_areas,
    )
    from fiona.errors import DriverError

    print(f"Downloading data for CA in year {year}")
    
    loaders = {
        f"COUNTIES_{year}":counties,
        f"TRACTS_{year}":tracts,
        f"BLOCK_GROUPS_{year}":block_groups,
        f"BLOCKS_{year}":blocks,
        f"PLACES_{year}":places,
        f"PUMAS_{year}":pumas,
        f"COUNTY_SUBDIVISIONS_{year}":county_subdivisions,
        f"PRIMARY_SECONDARY_ROADS_{year}":primary_secondary_roads,      
        f"NATION_{year}":nation,
        f"DIVISIONS_{year}":divisions,
        f"REGIONS_{year}":regions,
        f"STATES_{year}":states,
        f"COASTLINE_{year}":coastline,
        f"URBAN_AREAS_{year}":urban_areas,
        f"PRIMARY_ROADS_{year}":primary_roads,
        f"RAILS_{year}":rails,
        f"NATIVE_AREAS_{year}":native_areas,
        f"TRIBAL_BLOCK_GROUPS_{year}":tribal_block_groups,
        f"TRIBAL_SUBDIVISIONS_NATIONAL_{year}":tribal_subdivisions_national,
        f"CORE_BASED_STATISTICAL_AREAS_{year}":core_based_statistical_areas,
        f"COMBINED_STATISTICAL_AREAS_{year}":combined_statistical_areas
    }
    
    state = "CA"

    try:
        for table_name, loader in loaders.items():
            gdf_to_snowflake(
                loader(state=state, year=year).reset_index(drop=True),
                conn,
                table_name=table_name,
                cluster=False,
            )
    except TypeError:
        for table_name, loader in loaders.items():
            gdf_to_snowflake(
                loader(year=year).reset_index(drop=True),
                conn,
                table_name=table_name,
                cluster=False,
            )
    except (ValueError, DriverError):
        pass
    
#using .reset_index(drop=True) to address the following UserWarning: Pandas Dataframe has non-standard index of type <class 'pandas.core.indexes.base.Index'> which will not be written. Consider changing the index to pd.RangeIndex(start=0,...,step=1) or call reset_index() to keep index as column(s)

if __name__ == "__main__":
    
    # TODO: perhaps make a real CLI here.
    import sys
    N_ARGS = 2
    assert len(sys.argv) == N_ARGS, "Expecting 1 argument: year (four digits)"
    
    year = sys.argv[1]
    
    conn = snowflake_connection_from_environment(
        schema=f"TIGER_{year}",
        client_session_keep_alive=True,
    )

    load_geo_data(conn, year)
    
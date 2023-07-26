from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_us_geo_data(conn, year: str) -> None:
    """Load U.S. Census geo data into Snowflake."""
    from pygris import (
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
    )

    print(f"Downloading data for the U.S. in year {year}")

    cache = True
    dfs = []

    nat = nation(year=year, cache=cache)
    nat["year"] = year
    dfs.append(nat)

    division = divisions(year=year, cache=cache)
    division["year"] = year
    dfs.append(division)

    region = regions(year=year, cache=cache)
    region["year"] = year
    dfs.append(region)

    state = states(year=int(year), cache=cache)
    state["year"] = year
    dfs.append(state)

    coastln = coastline(year=int(year), cache=cache)
    coastln["year"] = year
    dfs.append(coastln)

    # core_based_statistical_area = core_based_statistical_areas(year=year, cache=cache)
    # core_based_statistical_area['year'] = year
    # dfs.append(core_based_statistical_area) #avaialble for 2021, but not 2022

    # combined_statistical_area = combined_statistical_areas(year=year, cache=cache)
    # combined_statistical_area['year'] = year
    # dfs.append(combined_statistical_area) #avaialble for 2021, but not 2022

    urban_area = urban_areas(year=year, cache=cache)
    urban_area["year"] = year
    dfs.append(urban_area)

    primary_road = primary_roads(year=year, cache=cache)
    primary_road["year"] = year
    dfs.append(primary_road)

    rail = rails(year=year, cache=cache)
    rail["year"] = year
    dfs.append(rail)

    native_area = native_areas(year=year, cache=cache)
    native_area["year"] = year
    dfs.append(native_area)

    tribal_block_group = tribal_block_groups(year=year, cache=cache)
    tribal_block_group["year"] = year
    dfs.append(tribal_block_group)

    tribal_subdivisions_nat = tribal_subdivisions_national(year=int(year), cache=cache)
    tribal_subdivisions_nat["year"] = year
    dfs.append(tribal_subdivisions_nat)

    table_names = [
        "NATION_" + year,
        "DIVISIONS_" + year,
        "REGIONS_" + year,
        "STATES_" + year,
        "COASTLINE_" + year,
        "CORE_BASED_STATISTICAL_AREAS_" + year,
        "COMBINED_STATISTICAL_AREAS_" + year,
        "URBAN_AREAS_" + year,
        "PRIMARY_ROADS_" + year,
        "RAILS_" + year,
        "NATIVE_AREAS_" + year,
        "TRIBAL_BLOCK_GROUPS_" + year,
        "TRIBAL_SUBDIVISIONS_NATIONAL_" + year,
    ]

    for x in range(len(dfs)):
        gdf_to_snowflake(
            dfs[x].reset_index(drop=True),
            conn,
            table_name=table_names[x],
            cluster=False,
        )


if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="CENSUS_2022",  # TODO: figure out a way to make the year a variable of the user input
        client_session_keep_alive=True,
    )

    import sys

    # TODO: perhaps make a real CLI here.
    N_ARGS = 2
    assert len(sys.argv) == N_ARGS, "Expecting 1 argument: year (four digits)"
    load_us_geo_data(conn, sys.argv[1])

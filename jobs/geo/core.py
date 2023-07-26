from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_ca_geo_data(conn, year: str) -> None:
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
    )

    print(f"Downloading data for CA in year {year}")

    state = "CA"
    cache = True
    dfs = []

    county = counties(state=state, year=year, cache=cache)
    county["year"] = year
    dfs.append(county)

    tract = tracts(state=state, year=year, cache=cache)
    tract["year"] = year
    dfs.append(tract)

    block_group = block_groups(state=state, year=year, cache=cache)
    block_group["year"] = year
    dfs.append(block_group)

    block = blocks(state=state, year=year, cache=cache)
    block["year"] = year
    dfs.append(block)

    place = places(state=state, year=year, cache=cache)
    place["year"] = year
    dfs.append(place)

    puma = pumas(state=state, year=int(year), cache=cache)
    puma["year"] = year
    dfs.append(puma)

    county_subdivision = county_subdivisions(state=state, year=year, cache=cache)
    county_subdivision["year"] = year
    dfs.append(county_subdivision)

    primary_secondary_road = primary_secondary_roads(
        state=state, year=year, cache=cache
    )
    primary_secondary_road["year"] = year
    dfs.append(primary_secondary_road)

    table_names = [
        "COUNTIES_" + year,
        "TRACTS_" + year,
        "BLOCK_GROUPS_" + year,
        "BLOCKS_" + year,
        "PLACES_" + year,
        "PUMAS_" + year,
        "COUNTY_SUBDIVISIONS_" + year,
        "PRIMARY_SECONDARY_ROADS_" + year,
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
    load_ca_geo_data(conn, sys.argv[1])

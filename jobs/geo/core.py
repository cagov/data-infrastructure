from __future__ import annotations

from jobs.utils.snowflake import gdf_to_snowflake, snowflake_connection_from_environment


def load_geo_data(conn, year: str) -> None:
    """Load Census geo data into Snowflake."""
    import geopandas
    import pygris
    from pygris import (nation, divisions, regions, states, counties, tracts, block_groups, blocks, places, 
                        pumas, coastline, core_based_statistical_areas, combined_statistical_areas, 
                        metro_divisions, county_subdivisions, urban_areas, primary_roads, primary_secondary_roads, 
                        rails, native_areas, tribal_block_groups, tribal_subdivisions_national)

    print(f"Downloading data for CA in year {year}")

    # Omitted the following:
    # school_districts, state_legislative_districts,  as they are a bit more nuanced
    # area_water, linear_water, and roads require a list of all 58 CA counties
    # voting_districts only available for 2012 and 2020 and zctas only available for 2000 and 2010
    # new_england and alaska_native_regional_corporations since they doesn't make sense
    # congressional_districts, tribal_census_tracts, landmarks, metro_divisions, and military were unable to be imported or threw errors

    state = 'CA'
    cache = True
    dfs = []

    nat = nation(year=year, cache=cache)
    nat['year'] = year
    dfs.append(nat)

    division = divisions(year=year, cache=cache)
    division['year'] = year 
    dfs.append(division)

    region = regions(year=year, cache=cache)
    region['year'] = year
    dfs.append(region)

    s = states(year=int(year), cache=cache)
    s['year'] = year
    dfs.append(s)

    county = counties(state=state, year=year, cache=cache)
    county['year'] = year
    dfs.append(county)

    tract = tracts(state=state, year=year, cache=cache)
    tract['year'] = year
    dfs.append(tract)

    block_group = block_groups(state=state, year=year, cache=cache)
    block_group['year'] = year
    dfs.append(block_group)

    block = blocks(state=state, year=year, cache=cache)
    block['year'] = year
    dfs.append(block)

    place = places(state=state, year=year, cache=cache)
    place['year'] = year
    dfs.append(place)

    puma = pumas(state=state, year=int(year), cache=cache)
    puma['year'] = year
    dfs.append(puma)

    coastln = coastline(year=int(year), cache=cache)
    coastln['year'] = year
    dfs.append(coastln)

    # core_based_statistical_area = core_based_statistical_areas(year=year, cache=cache)
    # core_based_statistical_area['year'] = year
    # dfs.append(core_based_statistical_area) #avaialble for 2021, but not 2022

    # combined_statistical_area = combined_statistical_areas(year=year, cache=cache)
    # combined_statistical_area['year'] = year
    # dfs.append(combined_statistical_area) #avaialble for 2021, but not 2022

    county_subdivision = county_subdivisions(state=state, year=year, cache=cache)
    county_subdivision['year'] = year
    dfs.append(county_subdivision)

    urban_area = urban_areas(year=year, cache=cache)
    urban_area['year'] = year
    dfs.append(urban_area)

    primary_road = primary_roads(year=year, cache=cache)
    primary_road['year'] = year
    dfs.append(primary_road)

    primary_secondary_road = primary_secondary_roads(state=state, year=year, cache=cache)
    primary_secondary_road['year'] = year
    dfs.append(primary_secondary_road)

    rail = rails(year=year, cache=cache)
    rail['year'] = year
    dfs.append(rail)

    native_area = native_areas(year=year, cache=cache)
    native_area['year'] = year
    dfs.append(native_area)

    tribal_block_group = tribal_block_groups(year=year, cache=cache)
    tribal_block_group['year'] = year
    dfs.append(tribal_block_group)

    tribal_subdivisions_nat = tribal_subdivisions_national(year=int(year), cache=cache)
    tribal_subdivisions_nat['year'] = year
    dfs.append(tribal_subdivisions_nat)
    
    table_names = ["NATION_"+year, "DIVISIONS_"+year, "REGIONS_"+year, "STATES_"+year, "COUNTIES_"+year, "TRACTS_"+year, 
                   "BLOCK_GROUPS_"+year, "BLOCKS_"+year, "PLACES_"+year, "PUMAS_"+year,"CONGRESSIONAL_DISTRICTS_"+year,
                   "COASTLINE_"+year, "CORE_BASED_STATISTICAL_AREAS_"+year, "COMBINED_STATISTICAL_AREAS_"+year, 
                   "COUNTY_SUBDIVISIONS_"+year, "URBAN_AREAS_"+year, "PRIMARY_ROADS_"+year, "PRIMARY_SECONDARY_ROADS_"+year, 
                   "RAILS_"+year, "NATIVE_AREAS_"+year, "TRIBAL_BLOCK_GROUPS_"+year, "TRIBAL_SUBDIVISIONS_NATIONAL_"+year]

    for x in range(len(dfs)):
        gdf_to_snowflake(
            dfs[x].reset_index(drop=True),
            conn,
            table_name=table_names[x],
            cluster=False,
        )
      
        
if __name__ == "__main__":
    conn = snowflake_connection_from_environment(
        schema="CENSUS_2022", #TODO: figure out a way to make the year a variable of the user input
        client_session_keep_alive=True,
    )

    import sys

    # TODO: perhaps make a real CLI here.
    N_ARGS = 2
    assert (
        len(sys.argv) == N_ARGS
    ), "Expecting 1 argument: year (four digits)"
    load_geo_data(conn, sys.argv[1])
    
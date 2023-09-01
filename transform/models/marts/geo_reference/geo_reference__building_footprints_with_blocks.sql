/* Columns selected and renamed from footprints, blocks, and places
are reused in several places. To avoid repeating them with the possibility
for errors, we set them in lists/dictionaries where appropriate. */
{%- set footprint_cols = ['"release"', '"capture_dates_range"'] -%}

{%- set block_cols = {
      '"COUNTYFP20"': '"county_fips"',
      '"TRACTCE20"': '"tract"',
      '"BLOCKCE20"': '"block"',
      '"GEOID20"': '"block_geoid"',
  }
-%}

{%- set place_cols = {
     '"PLACEFP"': '"place_fips"',
     '"PLACENS"': '"place_ns"',
     '"GEOID"': '"place_geoid"',
     '"NAME"': '"place_name"',
     '"CLASSFP"': '"class_fips_code"',
  }
-%}

with footprints as (
    select * from {{ source('building_footprints', 'california_building_footprints') }}
),

blocks_source as (
    select * from {{ source('tiger_2022', 'blocks') }}
),

places_source as (
    select * from {{ source('tiger_2022', 'places') }}
),

blocks as (
    select
        {% for k, v in block_cols.items() -%}
            {{ k }} as {{ v }},
        {% endfor -%}
        "geometry"
    from blocks_source
),

places as (
    select
        {% for k, v in place_cols.items() -%}
            {{ k }} as {{ v }},
        {% endfor -%}
        {{ map_class_fips("CLASSFP") }} as "class_fips",
        "geometry"
    from places_source
),

footprints_with_blocks as (
    {{ spatial_join_with_deduplication(
       "footprints",
       "blocks",
       footprint_cols,
       block_cols.values(),
       left_geom='"geometry"',
       right_geom='"geometry"',
       prefix="b",
    ) }}
),

footprints_with_blocks_and_places as (
    {{ spatial_join_with_deduplication(
       "footprints_with_blocks",
       "places",
       footprint_cols + block_cols.values() | list,
       place_cols.values() | list + ['"class_fips"'],
       left_geom='"geometry"',
       right_geom='"geometry"',
       prefix="p",
    ) }}
)

select * from footprints_with_blocks_and_places

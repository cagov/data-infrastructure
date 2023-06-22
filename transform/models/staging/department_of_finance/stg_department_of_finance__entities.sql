{{ config(materialized="table") }}

{% set udf_schema = "PUBLIC" %}

{% call set_sql_header(config) %}

-- Warning! The SQL header is rendered separately from the rest of the template,
-- so we redefine the udf_schema in this block:
-- https://github.com/dbt-labs/dbt-core/issues/2793
{% set udf_schema = "PUBLIC" %}

create or replace temp function
    {{ udf_schema }}.reorder_name_for_alphabetization(name string)
returns string
language javascript
as
    $$
  // Replace fancy quotes with normal ones.
  const name = NAME.replace("’", "'");

  // Skip some exceptions
  const skip = ["Governor's Office"];
  if (skip.includes(name)) {
    return name;
  }

  // Annoying exceptions
  if (name.includes("Milton Marks") && name.includes("Little Hoover")) {
    return "Little Hoover Commission";
  }

  // Basic organizational types by which we don't want to organize.
  const patterns = [
    "Office of the Secretary (?:for|of)?",
    "Commission (?:on|for)?",
    "Board of Governors (?:for|of)?",
    "Board (?:of|on|for)?",
    "Agency (?:on|for)?",
    "(?:Department|Dept\\.) of",
    "Commission (?:on|for)?",
    "Committee (?:on|for)?",
    "Bureau of",
    "Council on",
    "Policy Council on",
    "Institute of",
    "Office (?:for|of)?",
    "Secretary (?:for|of)?",
    "", // Empty pattern to catch the prefixes below.
  ].map(
    // Lots of entities also start with throat clearing like "California this"
    // or "State that", which we also want to skip. Some also include a definite
    // article after the organizational unit.
    (p) =>
      "(?:California\\s+)?(?:Governor's\\s+)?(?:State\\s+|St\\.\\s+)?(?:Intergovernmental\\s+)?" +
      p +
      "(?:\\s+the)?"
  );

  const all_patterns = `(${patterns.join("|")})`;
  const re = RegExp(`^${all_patterns}\\s*(.+)$`); // \s* because some of the above eat spaces.
  const match = name.match(re);
  // Empty prefixes are matched, so skip if we don't get a full match.
  if (match && match[1] && match[2]) {
    return `${match[2].trim()}, ${match[1].trim()}`;
  } else {
    return name;
  }
$$
;

create or replace temp function {{ udf_schema }}.extract_name(name string)
returns string
language javascript
as $$
  const match = NAME.match(/^(.+?)(?:(?:\s*\(.*\)\s*|\s*[-–]+\s*[A-Z/ ]+)*)$/);
  if (match && match[1]) {
    return match[1];
  }
  return NAME;
$$
;
{%- endcall %}

with
base_entities as (select * from {{ source("state_entities", "base_entities") }}),

invalid_subagencies as (
    select *
    from base_entities
    where contains("name", 'no subagency') and contains("name", 'do not use')
),

entities as (
    select
        -- Extract the first portion of the entity as the name. The other
        -- two (optional) groups match parentheticals and things like
        -- "-- DO NOT USE" or " -- DOF USE ONLY"
        {{ udf_schema }}.extract_name("name") as name,
        coalesce(l3, l2, l1, b, a) as primary_code,
        a as agency_code,
        case
            when b in (select b from invalid_subagencies) then null else b
        end as subagency_code,
        l1,
        l2,
        l3,
        regexp_substr("name", '\\((.+?)\\)') as parenthetical,
        contains(lower("name"), 'do not use') as do_not_use,
        contains(lower("name"), 'abolished') as abolished,
        regexp_substr("name", '[A-Z/]+ USE ONLY') as restricted_use,
        "name" as name_raw
    from base_entities
),

entities_with_extras as (
    select
        *,
        {{ udf_schema }}.reorder_name_for_alphabetization(name) as name_alpha,
        case
            when coalesce(l3, l2, l1, subagency_code) is null
                then 'agency'
            when coalesce(l3, l2, l1) is null
                then 'subagency'
            when coalesce(l3, l2) is null
                then 'L1'
            when l3 is null
                then 'L2'
            else 'L3'
        end as ucm_level
    from entities
)

select *
from entities_with_extras

/*
Wanted to materialize using "ephemeral", but using a temporary
function requires a materialized table in BQ.
*/
{{ config(materialized="table") }}

{% call set_sql_header(config) %}
create temp function reorder_name_for_alphabetization(name string)
returns string
language js
as
    r"""
  // Replace fancy quotes with normal ones.
  name = name.replace("’", "'");

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
"""
;
{%- endcall %}

with
    base_entities as (select * from {{ source("state_entities", "base_entities") }}),

    invalid_subagencies as (
        select *
        from base_entities
        where
            contains_substr(name, "no subagency")
            and contains_substr(name, "do not use")
    ),

    entities as (
        select
            /*
            Extract the first portion of the entity as the name. The other
            two (optional) groups match parentheticals and things like
            "-- DO NOT USE" or " -- DOF USE ONLY"
            */
            regexp_extract(
                name, r"^(.+?)(?:(?:\s*\(.*\)\s*|\s*[-–]+\s*[A-Z/ ]+)*)$"
            ) as name,
            coalesce(l3, l2, l1, b, a) as primary_code,
            a as agency_code,
            case
                when b in (select b from invalid_subagencies) then null else b
            end as subagency_code,
            l1,
            l2,
            l3,
            regexp_extract(name, r"\((.+?)\)") as parenthetical,
            contains_substr(name, "do not use") as do_not_use,
            contains_substr(name, "abolished") as abolished,
            regexp_extract(name, r"[A-Z/]+ USE ONLY") as restricted_use,
            name as name_raw
        from base_entities
    ),

    entities_with_alphabetization as (
        select *, reorder_name_for_alphabetization(name) as name_alpha from entities
    )

select *
from entities_with_alphabetization

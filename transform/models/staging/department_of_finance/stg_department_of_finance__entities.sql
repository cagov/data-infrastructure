{{ config(materialized="ephemeral") }}

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
            name as name_raw,
        from base_entities
    )

select *
from entities







with
base_entities as (select * from RAW_DEV.state_entities.base_entities),

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
        PUBLIC.extract_name("name") as name,
        coalesce(l3, l2, l1, b, a) as primary_code,
        a as agency_code,
        case
            when b in (select invalid_subagencies.b from invalid_subagencies) then null else b
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
        PUBLIC.reorder_name_for_alphabetization(name) as name_alpha,
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
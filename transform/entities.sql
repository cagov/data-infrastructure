with
    invalid_subagencies as (
        select b
        from `caldata-sandbox.state_entities.base_entities`
        where
            contains_substr(name, "no subagency")
            and contains_substr(name, "do not use")
    ),
    entities as (
        select
            regexp_extract(
                name, r"^(.+?)(?:(?:\s*\(.*\)\s*|\s*[-–]+\s*DO.*)*)$"
            ) as name,
            a,
            case
                when b in (select b from invalid_subagencies) then null else b
            end as b,
            l1,
            l2,
            l3,
            regexp_extract(name, r"\((.+?)\)") as parenthetical,
            contains_substr(name, "do not use") as do_not_use,
            contains_substr(name, "abolished") as abolished,
            regexp_extract(name, r"[A-Z/]+ USE ONLY") as restricted_use,
            name as name_raw,
        from `caldata-sandbox.state_entities.base_entities`
    ),
    active_entities as (
        select name, a, b, l1, l2, l3
        from entities
        where do_not_use is false and abolished is false and restricted_use is null
    ),
    agencies as (select name, a as code from active_entities where b is null),
    subagencies as (
        select name, b as code, a as agency_code
        from active_entities
        where b is not null and l1 is null
    ),
    tier1 as (
        select name, l1 as code, a as agency_code, b as subagency_code
        from active_entities
        where l1 is not null and l2 is null
    ),
    tier2 as (
        select name, l2 as code, a as agency_code, b as subagency_code, l1 as tier1_code
        from active_entities
        where l2 is not null and l3 is null
    ),
    tier3 as (
        select
            name,
            l3 as code,
            a as agency_code,
            b as subagency_code,
            l1 as tier1_code,
            l2 as tier2_code
        from active_entities
        where l3 is not null
    )

select *
from tier3

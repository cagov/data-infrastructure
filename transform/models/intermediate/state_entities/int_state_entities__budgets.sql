
{{ config(materialized="view") }}

with
    active_entities as (select * from {{ ref("int_state_entities__active") }}),

    budgets as (select * from {{ ref("stg_ebudget__budgets") }}),

    active_entity_budgets as (
        select
            active_entities.primary_code,
            active_entities.name,
            active_entities.name_alpha,
            budgets.name as budget_name,
            budgets.budget_year_dollars
        from active_entities
        left join budgets on active_entities.primary_code = budgets.primary_code
    )

select *
from active_entity_budgets
order by primary_code asc

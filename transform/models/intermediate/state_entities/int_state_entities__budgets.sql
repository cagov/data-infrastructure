{{ config(materialized="view") }}

with
    active_entities as (select * from {{ ref("int_state_entities__active") }}),

    budgets as (select * from {{ ref("stg_ebudget__budgets") }}),

    active_agencies_and_departments as (
        select *
        from active_entities
        -- only select at deparment level or higher
        where coalesce(active_entities.l2, active_entities.l3) is null
    ),

    active_entity_budgets as (
        select
            active_agencies_and_departments.primary_code,
            active_agencies_and_departments.name,
            active_agencies_and_departments.name_alpha,
            budgets.name as budget_name,
            budgets.budget_year_dollars
        from active_agencies_and_departments
        left join
            budgets
            on active_agencies_and_departments.primary_code = budgets.primary_code
    )

select *
from active_entity_budgets
order by primary_code asc

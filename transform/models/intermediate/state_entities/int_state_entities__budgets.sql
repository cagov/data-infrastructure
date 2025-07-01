{{ config(materialized="view") }}

with
active_entities as (select * from {{ ref("int_state_entities__active") }}),

budgets as (select * from {{ ref("stg_ebudget__budgets") }}),

active_agencies_and_departments as (
    -- only select at deparment level or higher
    select * from active_entities
    where coalesce(l2, l3) is null
),

active_entity_budgets as (
    select
        active_agencies_and_departments.primary_code,
        active_agencies_and_departments.ucm_level,
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

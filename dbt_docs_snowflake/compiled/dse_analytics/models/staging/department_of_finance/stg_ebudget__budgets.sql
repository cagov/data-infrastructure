with
agencies_and_departments as (
    select *
    from RAW_DEV.state_entities.ebudget_agency_and_department_budgets
),

ebudget_budgets as (
    select
        "web_agency_cd" as primary_code,
        "legal_titl" as name,
        "all_budget_year_dols" as budget_year_dollars
    from agencies_and_departments
)

select *
from ebudget_budgets
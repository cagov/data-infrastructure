
    
    

select
    "org_cd" as unique_field,
    count(*) as n_records

from RAW_DEV.state_entities.ebudget_agency_and_department_budgets
where "org_cd" is not null
group by "org_cd"
having count(*) > 1



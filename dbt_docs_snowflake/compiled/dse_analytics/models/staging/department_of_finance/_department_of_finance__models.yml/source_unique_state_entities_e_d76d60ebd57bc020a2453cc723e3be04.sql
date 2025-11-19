
    
    

select
    "web_agency_cd" as unique_field,
    count(*) as n_records

from RAW_DEV.state_entities.ebudget_agency_and_department_budgets
where "web_agency_cd" is not null
group by "web_agency_cd"
having count(*) > 1



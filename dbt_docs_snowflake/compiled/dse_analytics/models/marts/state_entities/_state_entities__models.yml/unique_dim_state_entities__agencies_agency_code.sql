
    
    

select
    agency_code as unique_field,
    count(*) as n_records

from ANALYTICS_DEV.ci_should_not_create_this_schema_state_entities.dim_state_entities__agencies
where agency_code is not null
group by agency_code
having count(*) > 1



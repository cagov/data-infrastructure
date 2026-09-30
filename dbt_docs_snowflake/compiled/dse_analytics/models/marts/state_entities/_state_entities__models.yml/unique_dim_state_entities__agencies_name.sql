
    
    

select
    name as unique_field,
    count(*) as n_records

from ANALYTICS_DEV.ci_should_not_create_this_schema_state_entities.dim_state_entities__agencies
where name is not null
group by name
having count(*) > 1



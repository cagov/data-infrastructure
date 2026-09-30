
    
    

select
    primary_code as unique_field,
    count(*) as n_records

from TRANSFORM_DEV.ci_should_not_create_this_schema_state_entities.int_state_entities__active
where primary_code is not null
group by primary_code
having count(*) > 1



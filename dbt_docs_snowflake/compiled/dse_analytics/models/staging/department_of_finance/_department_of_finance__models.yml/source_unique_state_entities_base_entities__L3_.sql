
    
    

select
    "L3" as unique_field,
    count(*) as n_records

from RAW_DEV.state_entities.base_entities
where "L3" is not null
group by "L3"
having count(*) > 1



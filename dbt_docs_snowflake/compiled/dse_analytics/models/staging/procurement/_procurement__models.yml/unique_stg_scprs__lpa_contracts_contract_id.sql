
    
    

select
    contract_id as unique_field,
    count(*) as n_records

from TRANSFORM_DEV.ci_should_not_create_this_schema_procurement.stg_scprs__lpa_contracts
where contract_id is not null
group by contract_id
having count(*) > 1




    
    

select
    contract_id as unique_field,
    count(*) as n_records

from RAW_DEV.procurement.lpa_contracts
where contract_id is not null
group by contract_id
having count(*) > 1



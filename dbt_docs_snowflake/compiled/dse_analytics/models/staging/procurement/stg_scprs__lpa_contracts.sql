with
source as (
    select *
    from RAW_DEV.procurement.lpa_contracts
),

cleaned as (
    select
        contract_id,
        contract_description,
        supplier_id,
        supplier_name,
        nullif(buyer, 'nan') as buyer,
        begin_date,
        expire_date,
        contract_type,
        nullif(certification_type, 'nan') as certification_type,
        acquisition_type,
        status
    from source
)

select *
from cleaned
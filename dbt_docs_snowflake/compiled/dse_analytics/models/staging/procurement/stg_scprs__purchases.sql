with
source as (
    select *
    from RAW_DEV.procurement.scprs_purchases
),

cleaned as (
    select
        ltrim(purchase_document, '''') as purchase_document,
        cast(department as varchar) as department,
        department_name,
        first_item_title as description,
        ltrim(supplier_id, '''') as supplier_id,
        supplier_name,
        start_date,
        end_date,
        grand_total,
        ltrim(associated_pos, '''') as associated_pos,
        lpa_contract_id,
        acquisition_type
    from source
)

select *
from cleaned
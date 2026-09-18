with
contracts as (
    select *
    from TRANSFORM_DEV.ci_should_not_create_this_schema_procurement.stg_scprs__lpa_contracts
)

select *
from contracts
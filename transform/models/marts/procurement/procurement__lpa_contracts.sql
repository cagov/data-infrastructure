with
contracts as (
    select *
    from {{ ref('stg_scprs__lpa_contracts') }}
)

select *
from contracts

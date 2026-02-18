with
purchases as (
    select *
    from {{ ref('stg_scprs__purchases') }}
)

select *
from purchases

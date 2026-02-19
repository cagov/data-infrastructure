with
purchases as (
    select
        *,
        /* In the absense of a true department list, this is a pretty good
           mapping to agency via BU code based on the structure from here:
           https://dof.ca.gov/media/docs/accounting/accounting-policies-and-procedures
           /accounting-policies-and-procedures-uniform-codes-manual-organization-codes/3orgstruc.pdf
        */
        case
            when startswith(department, '0') or length(department) < 4 then 'Legislative, Judicial, Executive'
            when department::int >= 1000 and department::int < 2500 then 'Business, Consumer Services, and Housing'
            when department::int >= 2500 and department::int < 3000 then 'Transportation'
            when department::int >= 3000 and department::int < 3890 then 'Natural Resources'
            when department::int >= 3890 and department::int < 4000 then 'Environmental Protection'
            when department::int >= 4000 and department::int < 5210 then 'Health and Human Services'
            when department::int >= 5210 and department::int < 6000 then 'Corrections and Rehabilitation'
            when department::int >= 6000 and department::int < 7000 then 'Education'
            when department::int >= 7000 and department::int < 7500 then 'Labor and Workforce Development'
            when department::int >= 7500 and department::int < 8000 then 'Government Operations'
            when department::int >= 8000 then 'General Government'
        end as agency
    from {{ ref('stg_scprs__purchases') }}
)

select *
from purchases

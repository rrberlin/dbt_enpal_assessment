with src as (

    select *
    from {{ source('raw_crm_pipedrive', 'users') }} --public.users

)

select
    id::int as user_id,
    name::text as user_name,
    email::text as user_email,
    modified::timestamp as modified_ts
from src
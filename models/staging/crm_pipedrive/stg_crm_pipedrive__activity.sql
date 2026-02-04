with src as (

    select *
    from {{ source('raw_crm_pipedrive', 'activity') }} --public.activity

)

select
    activity_id::int as activity_id,
    type::text as activity_type_key,
    assigned_to_user::int as assigned_to_user_id,
    deal_id::int as deal_id,
    done::boolean as is_done,
    due_to::timestamp as due_to_ts
from src
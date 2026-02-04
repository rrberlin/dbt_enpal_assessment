with src as (

    select *
    from {{ source('raw_crm_pipedrive', 'activity_types') }} --public.activity_types

)

select
    id::int as activity_type_id,
    name::text as activity_type_name,
    cast (
    	case
        	when lower(active::text) = 'yes' then true
        	when lower(active::text) = 'no' then false
        	else null
    	end as boolean
    ) as is_active,
    type::text as activity_type_key  -- matches activity.activity_type_key
from src
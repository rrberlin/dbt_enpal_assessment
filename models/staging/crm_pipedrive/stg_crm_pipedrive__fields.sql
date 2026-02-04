with src as (

    select *
    from {{ source('raw_crm_pipedrive', 'fields') }} --public.fields

)

select
    id::int as field_id,
    field_key::text as field_key,
    name::text as field_name,
    case
        when field_value_options is null then null
        else field_value_options::jsonb
    end as field_value_options
from src
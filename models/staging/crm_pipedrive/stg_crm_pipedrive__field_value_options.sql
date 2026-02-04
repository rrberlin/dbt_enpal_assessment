with fields as (

    select *
    from {{ ref('stg_crm_pipedrive__fields') }} --public_staging.stg_crm_pipedrive__fields
    where field_value_options is not null

),

unnest as (

    select
        field_id,
        field_key,
        field_name,
        jsonb_array_elements(field_value_options) as option_obj
    from fields

)

select
    field_id,
    field_key,
    field_name,
    (option_obj ->> 'id')::int as option_id,
    (option_obj ->> 'label')::text as option_label
from unnest
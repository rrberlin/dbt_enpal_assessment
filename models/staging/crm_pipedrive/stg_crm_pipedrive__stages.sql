with src as (

    select *
    from {{ source('raw_crm_pipedrive', 'stages') }} --public.stages

)

select
    stage_id::int as stage_id,
    stage_name::text as stage_name
from src
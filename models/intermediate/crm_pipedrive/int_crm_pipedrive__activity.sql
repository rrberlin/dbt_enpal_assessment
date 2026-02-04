with activities as (

    select
        activity_id,
        activity_type_key,
        assigned_to_user_id,
        deal_id,
        is_done,
        due_to_ts
    from {{ ref('stg_crm_pipedrive__activity') }} --public_staging.stg_crm_pipedrive__activity

),

activity_types as (

    select
        activity_type_id,
        activity_type_name,
        activity_type_key
    from {{ ref('stg_crm_pipedrive__activity_type') }} --public_staging.stg_crm_pipedrive__activity_type

)

select
    a.activity_id,
    a.deal_id,
	a.activity_type_key,
    at.activity_type_name,
    a.assigned_to_user_id as user_id,
    a.due_to_ts,
    a.is_done
from activities a
left join activity_types at
	on at.activity_type_key = a.activity_type_key
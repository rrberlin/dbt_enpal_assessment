with deal_changes as (

    select
        deal_id,
        change_time_ts,
        changed_field_key,
        new_value_raw,
        new_value_stage_id,
        new_value_user_id,
        new_value_lost_reason_id,
        new_value_deal_add_time_ts
    from {{ ref('stg_crm_pipedrive__deal_changes') }} --public_staging.stg_crm_pipedrive__deal_changes

),

deal_owner as (

	select
		deal_id,
		new_value_user_id as owner,
		change_time_ts as owner_from_ts,
  		lead(change_time_ts) OVER (PARTITION BY deal_id ORDER BY change_time_ts) AS owner_to_ts

	from deal_changes dc
	where new_value_user_id is  not null

)

select *
from deal_owner
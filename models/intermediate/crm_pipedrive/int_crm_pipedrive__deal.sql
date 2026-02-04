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

deal_add_time as (

	select
		deal_id,
		new_value_deal_add_time_ts as created_at
	from deal_changes
	where new_value_deal_add_time_ts is not null --only not null for deal_add changes as per stg_crm_pipedrive__deal_changes
),

deal_owner as (

	select
		deal_id,
		new_value_user_id as owner,
		change_time_ts as owner_from_ts,
  		lead(change_time_ts) OVER (PARTITION BY deal_id ORDER BY change_time_ts) AS owner_to_ts
	from deal_changes dc
	where new_value_user_id is not null --only not null for user changes as per stg_crm_pipedrive__deal_changes

),

max_deal_stage as (

	select
		deal_id,
		max(new_value_stage_id) as max_stage_id
	from deal_changes
	where new_value_stage_id is not null --only not null for state changes as per stg_crm_pipedrive__deal_changes
	group by deal_id

),

stages as (

	select
		stage_id,
		stage_name
	from {{ ref('stg_crm_pipedrive__stages') }} --public_staging.stg_crm_pipedrive__stages

),

deal_lost_reason as (

	select
		deal_id,
		new_value_lost_reason_id as lost_reason_id,
		change_time_ts as lost_reason_ts
	from deal_changes
	where new_value_lost_reason_id is not null --only not null for loast reason changes as per stg_crm_pipedrive__deal_changes
),

lost_reason as (

    select
        option_id as lost_reason_id,
        option_label as lost_reason_name
    from {{ ref('stg_crm_pipedrive__field_value_options') }} --public_staging.stg_crm_pipedrive__field_value_options
    where field_key = 'lost_reason'

),

final as (

	select
		dc.deal_id,
		dat.created_at,
		dow.owner as current_owner,
		mds.max_stage_id as max_stage_reached,
		st.stage_name as max_stage_reached_name,
		dlr.lost_reason_id,
		lr.lost_reason_name,
		dlr.lost_reason_ts
	from (select distinct deal_id from deal_changes) dc
	left join deal_add_time dat
		on dc.deal_id = dat.deal_id
	left join (select deal_id, owner from deal_owner where owner_to_ts is null /*gets current owner*/) dow
		on dc.deal_id = dow.deal_id
	left join max_deal_stage mds
		on dc.deal_id = mds.deal_id
	left join stages st
		on mds.max_stage_id = st.stage_id
	left join deal_lost_reason dlr
		on dc.deal_id = dlr.deal_id
	left join lost_reason lr
		on dlr.lost_reason_id = lr.lost_reason_id
	
)

select *
from final

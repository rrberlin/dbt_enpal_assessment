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

stages as (

	select
		stage_id,
		stage_name
	from {{ ref('stg_crm_pipedrive__stages') }} --public_staging.stg_crm_pipedrive__stages

),

max_deal_stage as (

	select
		deal_id,
		max(new_value_stage_id) as max_stage_id
	from deal_changes
	where new_value_stage_id is not null --only not null for state changes as per stg_pipedrive__deal_changes
	group by deal_id

),

deal_stages as (

	select
		dc.deal_id,
		dc.new_value_stage_id as stage_id,
		st.stage_name,
		dc.change_time_ts as stage_entered_ts
	from deal_changes dc
	left join stages st
		on dc.new_value_stage_id = st.stage_id
	where new_value_stage_id is not null --only not null for state changes as per stg_pipedrive__deal_changes

),

final as (

	select
        mds.deal_id,
        gs.stage_id,
        st.stage_name,
        ds.stage_entered_ts,
        case when ds.stage_entered_ts is null then true else false end as was_skipped,
        case when mds.max_stage_id = ds.stage_id then true else false end as max_stage_id,
		min(stage_entered_ts) over (partition by mds.deal_id order by gs.stage_id rows between current row and unbounded following) as helper_stage_entered_ts
    from max_deal_stage mds
    -- expand each deal into stages 1..max_stage_id
    join lateral (
        select generate_series(1, mds.max_stage_id) as stage_id
    ) gs on true
    -- attach stage names for all stage ids
    left join stages st
        on st.stage_id = gs.stage_id
    -- attach actual entry timestamps when the stage happened
    left join deal_stages ds
        on ds.deal_id = mds.deal_id
       and ds.stage_id = gs.stage_id

)

select *
from final
order by deal_id, stage_id
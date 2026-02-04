--VersionA: The deal count for deals is based on the timestamp when the deal moved between stages. Use this when looking at which deals moved between stages in a given month (approximately for skipped stages).

with deal_stages_funnel as (

    select
        deal_id,
        --stage_entered_ts, --use this instead of helper_stage_entered_ts when ignoring skipped stages
        helper_stage_entered_ts as report_date, --use this instead of stage_entered_ts when NOT ignoring skipped stages
        'Step ' || stage_id::text as funnel_step,
        stage_name as kpi_name
    from {{ ref('int_crm_pipedrive__deal_stage_details') }} --public_intermediate.int_crm_pipedrive__deal_stage_details
	--where was_skipped is false --use this together with stage_entered_ts when ignoring skipped stages
    
),

activity_stage_funnel as (

	select
		deal_id,
		due_to_ts as report_date, --we have no actual done timestamp so we have to assume that done actions were performed at due_to date/timestamp
		case
			when activity_type_key = 'meeting' then 'Step 2_1'
			when activity_type_key = 'sc_2' then 'Step 3_1'
		end as funnel_step,
		activity_type_name as kpi_name
	from {{ ref('int_crm_pipedrive__activity') }} --public_intermediate.int_crm_pipedrive__activity
	where
		is_done = true
		and activity_type_key in ('meeting', 'sc_2')

),

final as (

	select * from deal_stages_funnel
	union all
	select * from activity_stage_funnel
	
)

select
	left(date_trunc('month', report_date)::text, 7) as month,
	kpi_name,
	funnel_step,
	count(deal_id) as deals_count
from final
group by
	month,
	kpi_name,
	funnel_step
order by
	month,
	funnel_step

--VersionB: The deal count for deals is based on the timestamp when the deal was created. Use this when looking at cohorts of deals (approximately for skipped stages).

with deal_created_at as (

    select
        deal_id,
        created_at
    from {{ ref('int_crm_pipedrive__deal') }} --public_intermediate.int_crm_pipedrive__deal
    
),

deal_stages_funnel as (

    select
        dsd.deal_id,
        dca.created_at as report_date,
        'Step ' || dsd.stage_id::text as funnel_step,
        dsd.stage_name as kpi_name
    from {{ ref('int_crm_pipedrive__deal_stage_details') }} as dsd --public_intermediate.int_crm_pipedrive__deal_stage_details
	left join deal_created_at dca
		on dsd.deal_id = dca.deal_id
    --where was_skipped is false --use this when ignoring skipped stages
    
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

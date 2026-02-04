with src as (

    select *
    from public.deal_changes --{{ source('raw_crm_pipedrive', 'deal_changes') }} --public.deal_changes
    WHERE not (
    (deal_id = 399956 AND change_time::time = '18:27:27')
    OR (deal_id = 554294 AND change_time::time = '06:38:53')
    OR (deal_id = 556338 AND change_time::time = '04:51:56')
    OR (deal_id = 851850 AND change_time::time = '00:01:17')
    OR (deal_id = 955417 AND change_time::time = '20:10:54')
	) --removed 5 duplicated deal_ids based on results of exploratory data analysis. However, ideally this should not be hardcoded in stg model and be solved in Pipedrive CRM or based on a business logic that can eliminate all duplicates (also potential future duplicates)
    	
),

data_types as (

    select
        deal_id::int as deal_id,
        change_time::timestamp as change_time_ts,
        changed_field_key::text as changed_field_key,
        new_value::text as new_value_raw
    from src

),

-- Add columns with correct data_type for new_value so downstream models don't need repeated CASE casts.
-- still keep new_value_raw to have full raw date represented in staging layer
final_data_types as (

    select
        *,
        case
	        when changed_field_key = 'stage_id' then new_value_raw::int
	    end as new_value_stage_id,
        case
	        when changed_field_key = 'user_id' then new_value_raw::int
	    end as new_value_user_id,
        case
	        when changed_field_key = 'lost_reason' then new_value_raw::int
	    end as new_value_lost_reason_id,
        case
	        when changed_field_key = 'add_time' then new_value_raw::timestamp
	    end as new_value_deal_add_time_ts
    from data_types

)

select
    deal_id,
    change_time_ts,
    changed_field_key,
    new_value_raw,
    new_value_stage_id,
    new_value_user_id,
    new_value_lost_reason_id,
    new_value_deal_add_time_ts
from final_data_types
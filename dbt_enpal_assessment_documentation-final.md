# DBT Enpal Assessment – Documentation Robert Ruck

In this document, I document my findings during the **Data Exploration** phase and explain my decisions during the **Data Modeling** phase.

---

## 1. Data Exploration

### 1.1 General

Pipedrive CRM is a sales-focused customer relationship management system centered around **deals**, **activities** and **users**.

---

### 1.2 Overview of raw/source tables and key findings

#### 1.2.1 Activity table

- Contains information about activities (e.g. Sales Calls) scheduled (and done) in Pipedrive CRM
- Rows: **4,579**

**Columns & observations:**

- **activity\_id**

  - 4,568 unique activity\_ids
  - 11 duplicated activity\_ids
  - Duplicates have different `assigned_to_user_id` and `deal_id`
  - In a real-world project, I would clarify this with business stakeholders
  - Since duplicates are linked to different deals and at most one row per duplicated activity has `done = true`, I would remove no potential duplicates (even though `activity_id` should be ideally the primary key)

- **type**

  - Type of activity

- **assigned\_to\_user**

  - 1,650 unique users
  - Each user has between 1 and 11 linked activities

- **deal\_id**

  - 4,572 unique deal\_ids
  - 7 duplicated deal\_ids
  - Duplicates have different `assigned_to_user_id` and `activity_id`
  - This is expected behavior in my opinion, as deals can have multiple activities
  - Requires caution when joining on `deal_id`

- **done**

  - Boolean flag indicating whether the activity was completed

- **due\_to**

  - Timestamp indicating when the activity should be performed
  - Range: `2024-01-01` – `2024-09-13`

---

#### 1.2.2 Activity\_type table

- Contains information about activity types used in the activity table
- Rows: **4**

**Columns:**

- **id**

  - Primary key of the activity type

- **name**

  - Display name used in sales funnel reporting
  - Example: “Sales Call 1” instead of type “meeting”

- **active**

  - Yes/No flag
  - Likely indicates whether the activity type can still be selected in Pipedrive
  - Type “follow up” is no longer active (to be confirmed with business stakeholder in a real world project)

- **type**

  - Activity type (matches `type` in the activity table)

---

#### 1.2.3 deal\_changes table

- Contains information about deals and all changes made to them
- Includes timestamps for creation, stage changes, owner assignments and changes, and lost reasons
- Rows: **15,406**

**Columns & observations:**

- **deal\_id**

  - 1,995 unique deal\_ids
  - 5 duplicated deal\_ids
  - Duplicates where identified because there are 2,000 `add_time` and 2,000 `lost_reason` entries and at least the `add_time` should only exists once per deal
  - In a real-world project, I would clarify this with business stakeholders and data engineers if needed
  - Since in my understanding each deal should only enter the sales funnel pipeline once I will remove these duplicates  in the staging layer (as said in real world case I would check first if this is the right thing to do)

- **change\_time**

  - Timestamp of the changes to the deal
  - Range: `2024-01-01` – `2025-03-11`

- **changed\_field\_key**

  - Identifies which field changed
  - Possible values:
    - `add_time`
    - `lost_reason`
    - `stage_id`
    - `user_id`

- **new\_value**

  - Stored as VARCHAR
  - Needs transformation:
    - `add_time` → timestamp
    - `lost_reason`, `stage_id`, `user_id` → integer

**Further observations:**

- `add_time` range matches activity `due_to` range (`2024-01-01` – `2024-09-13`)
- `change_time` for `stage_ids`extends until `2025-02`, capturing later stage movements
- Reporting deals on deal creation month (`2024-01-01` – `2024-09-13` ) will bring a good comparison of deal cohorts and also align with activity timestamps
- Reporting deals on `change_time` for `stage_ids` (`2024-01 – 2025-02` ) will show when stage changes actually happened, but will lead to skewed counts (more stage 1 counts in `2024-01`, more later stage counts (and almost no stage 1 counts) after `2024-10`)
- Every deal has a `lost_reason`, and it is always the final change → suggests only **lost deals** are included in the deal changes table -> In a real-world project, I would clarify this with business stakeholders and data engineers if needed
- There are more user\_ids (2500) than deal\_ids (2000) due to ownership changes
- Deals:
  - Always start in stage 1 (2000 deal changes with `stage_id = 1`)
  - Only move forward (stage 1 → 9)
  - Can skip stages (e.g. 1 → 3), which may indicate tracking issues. In my understanding a deal should not skip stages as you almost always want to perform each funnel stage (e.g. going directly from lead generation (step 1) to needs assessment (step 3) we would skip qualifying the lead and may end up with a customer that is not part of our ideal customer profile and causes more effort then revenue for us) -> In a real-world project, I would clarify this with business stakeholders and data engineers if needed

---

#### 1.2.4 fields table

- Contains metadata for `changed_field_key` used in `deal_changes`
- Rows: **4**

**Columns:**

- **id**

  - Primary key

- **field\_key**

  - Matches `changed_field_key` in `deal_changes`

- **name**

  - Field name (most likely how it is displayed in Pipedrive CRM)

- **field\_value\_options**

  - NULL for `add_time` and `user_id`
  - JSONB for `stage_id` and `lost_reason`

---

#### 1.2.5 stages table

- Contains information about sales funnel stages
- Rows: **9**

**Columns:**

- **id**

  - Primary key

- **stage\_name**

  - Name of the stage
  - Matches labels in `field_value_options` for `stage_id`

---

#### 1.2.6 users table

- Contains information about Pipedrive users (e.g. sales reps)
- Rows: **1,787**

**Columns:**

- **id**

  - Primary key
  - Links to:
    - `assigned_to_user` in activity table
    - `new_value` in `deal_changes` where `changed_field_key = 'user_id'`

- **name**

  - User name

- **email**

  - User email address

- **modified**

  - Timestamp of last modification
  - Range: `2024-01-02` – `2024-10-28`

---

#### 1.2.7 Further observations

- When joining **activity** and **deal\_changes** on `deal_id`, only **8 deal\_ids** appear in both tables
- In a real-world scenario, I would be clarifing with business stakeholders and data engineers, as I would have expected that most deals should have at least one linked activity (e.g. a sales call) to drive the the deal forward

---

## 2. Data Modeling

### 2.1 raw/source layer

- I edited the .yml file to define all sources

### 2.2 staging layer

- I used a repeatable template (src CTE) for all staging models and created a staging model for each source table and casted data types if needed
- For stg\_crm\_pipedrive\_\_deal\_changes I removed 5 duplicated deal\_ids based on results of exploratory data analysis. However, ideally this should not be hardcoded in stg model and be solved in Pipedrive CRM or based on a business logic that can eliminate all duplicates (also potential future duplicates) -> In a real-world project, I would clarify this with business stakeholders and data engineers if needed
- Furthermore, for stg\_crm\_pipedrive\_\_deal\_changes I expanded the new\_value into 4 columns based on changed\_field\_key as add\_time would need a different data type (timestamp) than the other changed fields
- Moreover, I have created an extra model (stg\_crm\_pipedrive\_\_field\_value\_options) to unnest the vales from the json in stg\_crm\_pipedrive\_\_fields model & stg\_crm\_pipedrive\_\_field was kept to keep a 1:1 representation of raw/source data in staging layer

### 2.3 intermediate layer

- I have created 4 models:
  - int\_crm\_pipedrive\_\_activity -> Activity table enriched with activity\_type\_name that serves as basis for all analyses regarding activities performed in Pipedrive CRM.
  - int\_crm\_pipedrive\_\_deal -> This model contains all information about the deal on a deal level (one row per deal) and serves as basis for all analyses regarding deal in Pipedrive CRM. For details about owners and stages you have int\_crm\_pipedrive\_\_deal\_owner\_details and int\_crm\_pipedrive\_\_deal\_stage\_details. In these models there are multiple rows per deal\_id however.
  - int\_crm\_pipedrive\_\_deal\_owner\_details -> This model breaks down ownership of deals as ownership of deals can change over time (as discovered in EDA). There is no personal information to the user\_id (like name or email) in this model to keep personal data contained in staging views. If personal information is required it should be added from staging to the reporting layer and the reporting model containing personal information should be tightly access controlled. This model can be used to attribute ownership for deals and single funnel steps a deal went through based on the timestamps from when until when a user was owner of a deal.
  - int\_crm\_pipedrive\_\_deal\_stage\_details -> This model breaks down stages of a deal as a deal goes through multiple stages in the sales funnel. Deals always starts at stage 1 and can go, but not have to go, up to stage 9. Deals only move forward, never backwards. Deals can skip stages (all as discovered in the initial EDA). This model can be used to report on funnel\_stages a deal went through and also identify skipped stages and assigns a proxy timestamp for skipped stages. The logic for the proxy timestamp is simply to go to the next not skipped stage change per deal and take this timestamp (In a real world project I would first inform Pipedrive users about the importance of moving the deal through the pipeline without skipping a stage and build a more elaborated solution together with business stakeholders for cases when stages are still skipped). To exclude skipped stages filter them out with (WHERE was\_skipped = false).

### 2.4 mart/reporting layer

- For the reporting models I have worked with the assumption that skipped funnel steps should be also counted (see 1.2.3 -> Further observations on deals) and counted them based on an approximated date for when the stage was changed. Like mentioned in a real world project I would clarify my understanding with business stakeholders first before building a model. I also wrote the reporting model in a way that you can quickly switch between a version which includes skipped stages and a version that ignores them.
- Furthermore, like mentioned in 1.2.3 -> Further observations on `add_time` and `change_time`, based on which date you build the report can change the outcome and the interpretation of the results:
  - For activities we have no actual done date of the activity in the activity table so we have to assume that the due\_to timestamp for done activities is also the time when the activity was done
  - For deals you can either use the deal creation date (version B) which aligns with the due\_to timestamp from activities (`2024-01-01` – `2024-09-13`) and can be used to analyse cohorts of deals created in the same month or use the timestamp for stage changes (version A) which gives you a picture about which stage movements happened in each month

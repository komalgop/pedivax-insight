# =============================================================================
# PediVax Insight — Genie Space Configuration
# =============================================================================
# This file tells you exactly what to paste into each section of your
# Genie Space. Follow the sections in order.
# =============================================================================


# =============================================================================
# SECTION A — GENIE SPACE TITLE & DESCRIPTION
# (Paste into Configure > Settings)
# =============================================================================

TITLE:
PediVax Insight — RSV Maternal-Infant Research Analytics

DESCRIPTION:
Ask questions about RSV (respiratory syncytial virus) neutralizing antibody
data from a 500-participant maternal-infant cohort study across 5 sites
(Emory, Grady, CHOA, UAB, Vanderbilt).

This space covers:
- Transplacental RSV antibody transfer from mother to infant
- Antibody waning over 6 months of follow-up
- Impact of maternal comorbidities on antibody titers
- Site-level enrollment and follow-up completion
- Equity analysis by race/ethnicity and insurance type

All data is synthetic and for portfolio demonstration purposes.

Try asking: "Which site enrolled the most preterm participants?"
Or: "How do titers compare between participants with and without gestational diabetes?"


# =============================================================================
# SECTION B — GENIE SPACE INSTRUCTIONS
# (Paste into Configure > Instructions > Text Instructions)
# =============================================================================

You are a research data assistant for a maternal-infant RSV vaccine/antibody study.

**Key definitions — always apply these:**
- Preterm: gestational age < 37 weeks (preterm_flag = 'Y')
- Extremely preterm: gestational age < 28 weeks
- Very preterm: gestational age 28–31 weeks
- Moderate/Late preterm: gestational age 32–36 weeks
- Term: gestational age >= 37 weeks (preterm_flag = 'N')
- Seropositive: antibody_titer >= 64 (seropositive_flag = 1)
- Timepoints in order: delivery → 6_weeks → 3_months → 6_months
- Log2 titer: log base-2 transformation of the antibody titer; higher = stronger response

**Data source guidance:**
- For seroconversion or titer by gestational age: use vw_seroconversion_by_gestational_age
- For comorbidity impact on titers: use vw_comorbidity_titer_impact
- For titer trends over time: use vw_longitudinal_titer_trend
- For enrollment counts and site summaries: use vw_enrollment_summary
- For race/ethnicity or equity questions: use vw_race_ethnicity_equity
- For individual participant lookups: query dim_participant directly

**When asked about "antibody transfer" or "transplacental transfer":**
Use delivery timepoint titers as the proxy measure of maternal-to-infant transfer.

**When asked about comorbidities:**
Available conditions: gestational_diabetes, preeclampsia, chronic_hypertension,
obesity_bmi_ge30, asthma, hiv, tobacco_use

**Always show:**
- The actual numbers (counts, percentages, means), not just direction
- Sample sizes so the user understands the denominator
- Timepoint or subgroup clearly labeled


# =============================================================================
# SECTION C — SQL EXPRESSIONS (Knowledge Store)
# (Add each one in Configure > Instructions > SQL Expressions)
# These teach Genie your business logic so it doesn't have to guess.
# =============================================================================

--- Expression 1 ---
Name: seropositive_definition
SQL:  seropositive_flag = 1
Description: A participant is seropositive when their RSV neutralizing antibody titer is >= 64 (reciprocal dilution).

--- Expression 2 ---
Name: preterm_definition
SQL:  preterm_flag = 'Y'
Description: Preterm is defined as gestational age strictly less than 37 completed weeks.

--- Expression 3 ---
Name: delivery_timepoint
SQL:  sample_timepoint = 'delivery'
Description: The delivery timepoint captures RSV antibody levels at birth, used as the primary measure of transplacental antibody transfer.

--- Expression 4 ---
Name: follow_up_complete
SQL:  follow_up_complete_flag = 1
Description: Participants who completed all scheduled follow-up visits through 6 months.


# =============================================================================
# SECTION D — EXAMPLE SQL QUERIES (Knowledge Store)
# (Add each one in Configure > Instructions > SQL Queries)
# These are pre-verified answers to common questions.
# =============================================================================

--- Query 1 ---
Question: What percentage of preterm infants were seropositive at delivery?
SQL:
SELECT
    preterm_flag,
    gestational_age_group,
    total_participants,
    seropositive_count,
    seropositive_pct
FROM pedivax_catalog.pedivax.vw_seroconversion_by_gestational_age
WHERE sample_timepoint = 'delivery'
ORDER BY preterm_flag DESC, gestational_age_group;

--- Query 2 ---
Question: How does gestational diabetes affect RSV antibody titers at delivery?
SQL:
SELECT
    comorbidity_type,
    comorbidity_status,
    participant_count,
    mean_titer_at_delivery,
    seropositive_pct
FROM pedivax_catalog.pedivax.vw_comorbidity_titer_impact
WHERE comorbidity_type = 'gestational_diabetes'
ORDER BY comorbidity_flag DESC;

--- Query 3 ---
Question: Show enrollment by site with follow-up completion rates
SQL:
SELECT
    site_id,
    SUM(total_enrolled)         AS total_enrolled,
    SUM(preterm_count)          AS preterm_count,
    ROUND(AVG(preterm_pct), 1)  AS avg_preterm_pct,
    SUM(follow_up_complete)     AS follow_up_complete,
    ROUND(AVG(follow_up_complete_pct), 1) AS avg_follow_up_pct
FROM pedivax_catalog.pedivax.vw_enrollment_summary
GROUP BY site_id
ORDER BY total_enrolled DESC;

--- Query 4 ---
Question: How do RSV antibody titers change over time for preterm vs term infants?
SQL:
SELECT
    preterm_flag,
    sample_timepoint,
    weeks_from_delivery,
    participants_with_sample,
    mean_titer,
    seropositive_pct
FROM pedivax_catalog.pedivax.vw_longitudinal_titer_trend
ORDER BY preterm_flag, weeks_from_delivery;

--- Query 5 ---
Question: Which maternal comorbidity is most associated with low antibody titers?
SQL:
SELECT
    comorbidity_type,
    MAX(CASE WHEN comorbidity_status = 'Present'
             THEN mean_titer_at_delivery END) AS mean_titer_with_comorbidity,
    MAX(CASE WHEN comorbidity_status = 'Absent'
             THEN mean_titer_at_delivery END) AS mean_titer_without_comorbidity,
    MAX(CASE WHEN comorbidity_status = 'Present'
             THEN mean_titer_at_delivery END)
    - MAX(CASE WHEN comorbidity_status = 'Absent'
               THEN mean_titer_at_delivery END) AS titer_difference
FROM pedivax_catalog.pedivax.vw_comorbidity_titer_impact
GROUP BY comorbidity_type
ORDER BY titer_difference ASC;

--- Query 6 ---
Question: Do RSV antibody outcomes differ by race or ethnicity?
SQL:
SELECT
    race_ethnicity,
    SUM(participant_count)          AS total_participants,
    ROUND(AVG(mean_titer_at_delivery), 1) AS avg_titer,
    ROUND(AVG(seropositive_pct), 1)       AS avg_seropositive_pct
FROM pedivax_catalog.pedivax.vw_race_ethnicity_equity
GROUP BY race_ethnicity
ORDER BY avg_titer DESC;

--- Query 7 ---
Question: Compare RSV antibody titers between the RSV_mAb arm and control arm over time
SQL:
SELECT
    study_arm,
    sample_timepoint,
    weeks_from_delivery,
    participants_with_sample,
    mean_titer,
    seropositive_pct
FROM pedivax_catalog.pedivax.vw_longitudinal_titer_trend
ORDER BY study_arm, weeks_from_delivery;

--- Query 8 ---
Question: How many participants completed all follow-up visits?
SQL:
SELECT
    follow_up_complete_flag,
    CASE WHEN follow_up_complete_flag = 1
         THEN 'Completed' ELSE 'Did not complete' END AS status,
    COUNT(*) AS participant_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM pedivax_catalog.pedivax.fact_enrollment
GROUP BY 1, 2
ORDER BY follow_up_complete_flag DESC;

%sql
-- =============================================================================
-- PediVax Insight — Notebook 2: Views & Metric Views
-- =============================================================================
-- Language: SQL 
-- Run each cell top to bottom.
-- These views are the "trusted analytic layer" that Genie reasons over.
-- Pre-joining and pre-aggregating here makes Genie faster and more accurate.
-- =============================================================================


-- Activate the database
USE CATALOG pedivax_catalog;
USE DATABASE pedivax;


-- -----------------------------------------------------------------------------
-- vw_seroconversion_by_gestational_age
-- Genie uses this to answer questions about antibody levels by preterm status
-- and gestational age group.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW pedivax_catalog.pedivax.vw_seroconversion_by_gestational_age
COMMENT 'RSV antibody seroconversion rates and mean titers grouped by gestational age and preterm status, at each sample timepoint.'
AS
SELECT
    p.preterm_flag,
    CASE
        WHEN p.gestational_age_weeks < 28 THEN 'Extremely preterm (<28w)'
        WHEN p.gestational_age_weeks BETWEEN 28 AND 31 THEN 'Very preterm (28-31w)'
        WHEN p.gestational_age_weeks BETWEEN 32 AND 36 THEN 'Moderate/Late preterm (32-36w)'
        ELSE 'Term (>=37w)'
    END                                         AS gestational_age_group,
    a.sample_timepoint,
    COUNT(DISTINCT p.participant_id)            AS total_participants,
    SUM(a.seropositive_flag)                    AS seropositive_count,
    ROUND(AVG(a.antibody_titer), 1)             AS mean_titer,
    ROUND(AVG(a.log2_titer), 3)                AS mean_log2_titer,
    ROUND(
        100.0 * SUM(a.seropositive_flag) / COUNT(*), 1
    )                                           AS seropositive_pct
FROM pedivax_catalog.pedivax.dim_participant p
JOIN pedivax_catalog.pedivax.fact_rsv_antibody a
    ON p.participant_id = a.participant_id
GROUP BY 1, 2, 3;


-- -----------------------------------------------------------------------------
-- vw_comorbidity_titer_impact
-- Genie uses this to answer questions like "do diabetic mothers have lower
-- antibody transfer?" — the core clinical question in the manuscript.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW pedivax_catalog.pedivax.vw_comorbidity_titer_impact
COMMENT 'Mean RSV antibody titers at delivery for participants with vs without each maternal comorbidity. Used to assess comorbidity impact on transplacental antibody transfer.'
AS
SELECT
    c.comorbidity_type,
    c.comorbidity_flag,
    CASE WHEN c.comorbidity_flag = 1 THEN 'Present' ELSE 'Absent' END AS comorbidity_status,
    COUNT(DISTINCT p.participant_id)    AS participant_count,
    ROUND(AVG(a.antibody_titer), 1)    AS mean_titer_at_delivery,
    ROUND(AVG(a.log2_titer), 3)       AS mean_log2_titer,
    ROUND(
        100.0 * SUM(a.seropositive_flag) / COUNT(*), 1
    )                                  AS seropositive_pct
FROM pedivax_catalog.pedivax.dim_participant p
JOIN pedivax_catalog.pedivax.dim_comorbidity c
    ON p.participant_id = c.participant_id
JOIN pedivax_catalog.pedivax.fact_rsv_antibody a
    ON p.participant_id = a.participant_id
   AND a.sample_timepoint = 'delivery'
GROUP BY 1, 2, 3;


-- -----------------------------------------------------------------------------
-- vw_longitudinal_titer_trend
-- Genie uses this to answer questions about how titers decay over time,
-- and whether decay rate differs by preterm status or study arm.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW pedivax_catalog.pedivax.vw_longitudinal_titer_trend
COMMENT 'Mean RSV antibody titers at each follow-up timepoint, broken down by preterm status and study arm. Used to evaluate longitudinal antibody waning.'
AS
SELECT
    p.preterm_flag,
    e.study_arm,
    a.sample_timepoint,
    CASE a.sample_timepoint
        WHEN 'delivery'   THEN 0
        WHEN '6_weeks'    THEN 6
        WHEN '3_months'   THEN 13
        WHEN '6_months'   THEN 26
    END                                     AS weeks_from_delivery,
    COUNT(DISTINCT p.participant_id)        AS participants_with_sample,
    ROUND(AVG(a.antibody_titer), 1)        AS mean_titer,
    ROUND(AVG(a.log2_titer), 3)           AS mean_log2_titer,
    ROUND(
        100.0 * SUM(a.seropositive_flag) / COUNT(*), 1
    )                                       AS seropositive_pct
FROM pedivax_catalog.pedivax.dim_participant p
JOIN pedivax_catalog.pedivax.fact_rsv_antibody a
    ON p.participant_id = a.participant_id
JOIN pedivax_catalog.pedivax.fact_enrollment e
    ON p.participant_id = e.participant_id
GROUP BY 1, 2, 3, 4;


-- -----------------------------------------------------------------------------
-- vw_enrollment_summary
-- Genie uses this for operational questions: site-level counts, demographics,
-- follow-up completion rates.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW pedivax_catalog.pedivax.vw_enrollment_summary
COMMENT 'Site-level enrollment summary including total participants, preterm proportions, demographic breakdown, and follow-up completion rates.'
AS
SELECT
    e.site_id,
    e.study_arm,
    COUNT(DISTINCT p.participant_id)                        AS total_enrolled,
    SUM(CASE WHEN p.preterm_flag = 'Y' THEN 1 ELSE 0 END)  AS preterm_count,
    ROUND(
        100.0 * SUM(CASE WHEN p.preterm_flag = 'Y' THEN 1 ELSE 0 END)
        / COUNT(DISTINCT p.participant_id), 1
    )                                                       AS preterm_pct,
    ROUND(AVG(p.maternal_age), 1)                          AS mean_maternal_age,
    SUM(e.follow_up_complete_flag)                         AS follow_up_complete,
    ROUND(
        100.0 * SUM(e.follow_up_complete_flag)
        / COUNT(DISTINCT p.participant_id), 1
    )                                                       AS follow_up_complete_pct
FROM pedivax_catalog.pedivax.dim_participant p
JOIN pedivax_catalog.pedivax.fact_enrollment e
    ON p.participant_id = e.participant_id
GROUP BY 1, 2;


-- -----------------------------------------------------------------------------
-- vw_race_ethnicity_equity
-- Genie uses this to answer equity-focused questions about whether antibody
-- outcomes differ by race/ethnicity — important for public health reporting.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW pedivax_catalog.pedivax.vw_race_ethnicity_equity
COMMENT 'RSV antibody outcomes at delivery stratified by race/ethnicity and insurance type. Used to evaluate equity in immune protection and access.'
AS
SELECT
    p.race_ethnicity,
    p.insurance_type,
    p.preterm_flag,
    COUNT(DISTINCT p.participant_id)    AS participant_count,
    ROUND(AVG(a.antibody_titer), 1)    AS mean_titer_at_delivery,
    ROUND(
        100.0 * SUM(a.seropositive_flag) / COUNT(*), 1
    )                                  AS seropositive_pct,
    ROUND(AVG(p.maternal_age), 1)     AS mean_maternal_age
FROM pedivax_catalog.pedivax.dim_participant p
JOIN pedivax_catalog.pedivax.fact_rsv_antibody a
    ON p.participant_id = a.participant_id
   AND a.sample_timepoint = 'delivery'
GROUP BY 1, 2, 3;


-- -----------------------------------------------------------------------------
-- Verify all views
-- -----------------------------------------------------------------------------
SELECT 'vw_seroconversion_by_gestational_age' AS view_name,
       COUNT(*) AS row_count
FROM pedivax_catalog.pedivax.vw_seroconversion_by_gestational_age

UNION ALL SELECT 'vw_comorbidity_titer_impact', COUNT(*)
FROM pedivax_catalog.pedivax.vw_comorbidity_titer_impact

UNION ALL SELECT 'vw_longitudinal_titer_trend', COUNT(*)
FROM pedivax_catalog.pedivax.vw_longitudinal_titer_trend

UNION ALL SELECT 'vw_enrollment_summary', COUNT(*)
FROM pedivax_catalog.pedivax.vw_enrollment_summary

UNION ALL SELECT 'vw_race_ethnicity_equity', COUNT(*)
FROM pedivax_catalog.pedivax.vw_race_ethnicity_equity

ORDER BY view_name;

-- ✅ If all 5 views show row counts > 0, proceed to Genie Space setup.

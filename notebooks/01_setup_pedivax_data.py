# =============================================================================
# PediVax Insight — Notebook 1: Synthetic Data Generation & Delta Table Setup
# =============================================================================
# This notebook:
#   1. Writes four Delta tables: dim_participant, dim_comorbidity,
#      fact_rsv_antibody, fact_enrollment
# NOTE: No real patient data is used. All values are statistically plausible
# but entirely fabricated.
# =============================================================================


# -----------------------------------------------------------------------------
# — Imports
# -----------------------------------------------------------------------------
import pandas as pd
import numpy as np
from datetime import date, timedelta
import random
from pyspark.sql import SparkSession
from pyspark.sql.types import *

spark = SparkSession.builder.getOrCreate()
random.seed(42)
np.random.seed(42)
print("✅ Imports done.")


# -----------------------------------------------------------------------------
# — Create Unity Catalog database
# -----------------------------------------------------------------------------
spark.sql("CREATE CATALOG IF NOT EXISTS pedivax_catalog")
spark.sql("CREATE DATABASE IF NOT EXISTS pedivax_catalog.pedivax")
spark.sql("USE pedivax_catalog.pedivax")
print("✅ Database pedivax_catalog.pedivax ready.")


# -----------------------------------------------------------------------------
# — Generate dim_participant (500 rows)
# -----------------------------------------------------------------------------
n = 500
sites = ["Emory", "Grady", "CHOA", "UAB", "Vanderbilt"]

# Gestational age: intentionally preterm-enriched (mirrors ROAPS design)
gest_ages = np.concatenate([
    np.random.randint(24, 37, size=200),   # preterm (40%)
    np.random.randint(37, 42, size=300)    # term (60%)
])
np.random.shuffle(gest_ages)

enrollment_start = date(2021, 6, 1)
enrollment_end   = date(2023, 12, 31)
date_range_days  = (enrollment_end - enrollment_start).days

participants = []
for i in range(1, n + 1):
    ga = int(gest_ages[i - 1])
    enroll_date = enrollment_start + timedelta(days=random.randint(0, date_range_days))
    participants.append({
        "participant_id":       f"PV{i:04d}",
        "site_id":              random.choice(sites),
        "gestational_age_weeks": ga,
        "preterm_flag":         "Y" if ga < 37 else "N",
        "delivery_mode":        random.choices(["vaginal", "c-section"], weights=[0.65, 0.35])[0],
        "enrollment_date":      enroll_date.isoformat(),
        "maternal_age":         int(np.random.normal(28, 5)),
        "race_ethnicity":       random.choices(
                                    ["Black/African American", "White", "Hispanic/Latino",
                                     "Asian", "Multiracial/Other"],
                                    weights=[0.42, 0.28, 0.18, 0.07, 0.05]
                                )[0],
        "insurance_type":       random.choices(["Medicaid", "Private", "Uninsured"],
                                               weights=[0.55, 0.38, 0.07])[0],
    })

dim_participant = pd.DataFrame(participants)
dim_participant["maternal_age"] = dim_participant["maternal_age"].clip(18, 45)

spark.createDataFrame(dim_participant).write \
    .format("delta") \
    .mode("overwrite") \
    .saveAsTable("pedivax_catalog.pedivax.dim_participant")

print(f"✅ dim_participant: {len(dim_participant)} rows written.")
dim_participant.head(3)


# -----------------------------------------------------------------------------
# — Generate dim_comorbidity (one row per participant per condition)
# -----------------------------------------------------------------------------
conditions = {
    "gestational_diabetes":   0.12,
    "preeclampsia":           0.08,
    "chronic_hypertension":   0.10,
    "obesity_bmi_ge30":       0.35,
    "asthma":                 0.09,
    "hiv":                    0.04,
    "tobacco_use":            0.11,
}

comorbidity_rows = []
for pid in dim_participant["participant_id"]:
    for condition, prevalence in conditions.items():
        comorbidity_rows.append({
            "participant_id":    pid,
            "comorbidity_type":  condition,
            "comorbidity_flag":  1 if random.random() < prevalence else 0,
        })

dim_comorbidity = pd.DataFrame(comorbidity_rows)

spark.createDataFrame(dim_comorbidity).write \
    .format("delta") \
    .mode("overwrite") \
    .saveAsTable("pedivax_catalog.pedivax.dim_comorbidity")

print(f"✅ dim_comorbidity: {len(dim_comorbidity)} rows written.")


# -----------------------------------------------------------------------------
# — Generate fact_rsv_antibody (4 timepoints per participant)
# -----------------------------------------------------------------------------
timepoints = ["delivery", "6_weeks", "3_months", "6_months"]

# Titer declines over time; preterm infants have lower baseline
antibody_rows = []
for _, row in dim_participant.iterrows():
    pid = row["participant_id"]
    preterm = row["preterm_flag"] == "Y"

    # Baseline titer at delivery — lower for preterm
    base_titer = np.random.lognormal(
        mean=3.8 if not preterm else 3.3,
        sigma=0.6
    )

    # Decay factor per timepoint
    decay = [1.0, 0.70, 0.45, 0.25]
    dropout_prob = [0.0, 0.05, 0.10, 0.18]   # increasing loss to follow-up

    for tp, d, dp in zip(timepoints, decay, dropout_prob):
        if random.random() < dp:
            continue   # simulate missing / lost-to-follow-up
        titer = base_titer * d * np.random.uniform(0.8, 1.2)
        titer = max(titer, 4)   # assay lower limit
        antibody_rows.append({
            "participant_id":   pid,
            "sample_timepoint": tp,
            "antibody_titer":   round(titer, 1),
            "seropositive_flag": 1 if titer >= 64 else 0,
            "log2_titer":       round(np.log2(titer), 3),
        })

fact_rsv_antibody = pd.DataFrame(antibody_rows)

spark.createDataFrame(fact_rsv_antibody).write \
    .format("delta") \
    .mode("overwrite") \
    .saveAsTable("pedivax_catalog.pedivax.fact_rsv_antibody")

print(f"✅ fact_rsv_antibody: {len(fact_rsv_antibody)} rows written.")


# -----------------------------------------------------------------------------
# — Generate fact_enrollment (one row per participant)
# -----------------------------------------------------------------------------
enrollment_rows = []
for _, row in dim_participant.iterrows():
    pid = row["participant_id"]
    enroll_date = date.fromisoformat(row["enrollment_date"])

    # Determine follow-up completion (preterm more likely to have complications)
    follow_up_complete = random.choices(
        [1, 0],
        weights=[0.78, 0.22] if row["preterm_flag"] == "N" else [0.65, 0.35]
    )[0]

    study_arm = random.choices(
        ["RSV_mAb", "control"],
        weights=[0.50, 0.50]
    )[0]

    enrollment_rows.append({
        "participant_id":         pid,
        "site_id":                row["site_id"],
        "enrollment_date":        row["enrollment_date"],
        "study_arm":              study_arm,
        "follow_up_complete_flag": follow_up_complete,
        "withdrawal_reason":      random.choice(
                                      ["moved", "lost_contact", "withdrew_consent", None, None, None]
                                  ) if follow_up_complete == 0 else None,
    })

fact_enrollment = pd.DataFrame(enrollment_rows)

spark.createDataFrame(fact_enrollment).write \
    .format("delta") \
    .mode("overwrite") \
    .saveAsTable("pedivax_catalog.pedivax.fact_enrollment")

print(f"✅ fact_enrollment: {len(fact_enrollment)} rows written.")


# -----------------------------------------------------------------------------
# — Quick sanity check
# -----------------------------------------------------------------------------
for table in ["dim_participant", "dim_comorbidity", "fact_rsv_antibody", "fact_enrollment"]:
    count = spark.sql(f"SELECT COUNT(*) as n FROM pedivax_catalog.pedivax.{table}").collect()[0]["n"]
    print(f"  pedivax.{table}: {count:,} rows")

print("\n✅ All tables ready. Proceed to Notebook 2.")

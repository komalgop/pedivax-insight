# PediVax Insight 🧬
### A Natural Language Research Analytics Assistant built on Databricks Genie

> Ask plain-English questions about RSV antibody data. Get back data-backed answers, tables, and charts — no SQL required.

---

## What This Is

PediVax Insight is a conversational data analytics tool built using **Databricks Genie Space**, demonstrating how natural language querying can make clinical research data accessible to investigators, coordinators, and stakeholders who don't write SQL.

The use case is modeled after real-world infectious disease research: a 500-participant maternal-infant cohort study examining **RSV (respiratory syncytial virus) neutralizing antibody transplacental transfer**, waning immunity over 6 months of follow-up, and the impact of maternal comorbidities on infant immune protection.

All data is **entirely synthetic** — statistically plausible but fabricated. No real patient data is used.

---

## What You Can Ask It

| Question | Data it uses |
|---|---|
| "What % of preterm infants were seropositive at delivery?" | vw_seroconversion_by_gestational_age |
| "Does gestational diabetes affect antibody titers?" | vw_comorbidity_titer_impact |
| "How do titers decay from delivery to 6 months?" | vw_longitudinal_titer_trend |
| "Which site had the best follow-up completion rate?" | vw_enrollment_summary |
| "Do outcomes differ by race/ethnicity?" | vw_race_ethnicity_equity |
| "Compare RSV_mAb arm vs control over time" | vw_longitudinal_titer_trend |

---

## Architecture

```
Synthetic CSV/Python data generation
         ↓
  Databricks Notebook (PySpark)
         ↓
  Delta Tables in Unity Catalog
  ├── dim_participant       (500 rows — demographics, gestational age)
  ├── dim_comorbidity       (3,500 rows — 7 conditions × 500 participants)
  ├── fact_rsv_antibody     (~1,850 rows — 4 timepoints, with dropout)
  └── fact_enrollment       (500 rows — site, arm, follow-up status)
         ↓
  SQL Views (pre-joined analytic layer)
  ├── vw_seroconversion_by_gestational_age
  ├── vw_comorbidity_titer_impact
  ├── vw_longitudinal_titer_trend
  ├── vw_enrollment_summary
  └── vw_race_ethnicity_equity
         ↓
  Genie Space (natural language chat interface)
  └── Tuned with: instructions, SQL expressions, 8 example queries
```

---

## Repo Structure

```
pedivax-insight/
│
├── README.md
├── notebooks/
│   ├── 01_setup_pedivax_data.py     ← Run first: generates data, writes Delta tables
│   └── 02_create_views.sql          ← Run second: creates all analytic views
└── genie/
    └── 03_genie_configuration.md    ← Paste-ready Genie Space setup instructions
```

---

## How to Reproduce This

### Prerequisites
- Free Databricks account (sign up at [databricks.com/learn/free-edition](https://databricks.com/learn/free-edition))
- No cloud account or credit card needed

### Step 1 — Run the data notebook
1. Create a new Python notebook in Databricks
2. Paste the contents of `notebooks/01_setup_pedivax_data.py`
3. Run all cells top to bottom
4. ✅ Verify: 4 Delta tables created in `pedivax_catalog.pedivax`

### Step 2 — Create the views
1. Create a new SQL notebook
2. Paste the contents of `notebooks/02_create_views.sql`
3. Run all cells top to bottom
4. ✅ Verify: 5 views all show row counts > 0

### Step 3 — Set up the Genie Space
1. Click **Genie** in the Databricks sidebar → **New**
2. Add all 5 views from `pedivax_catalog.pedivax` as data sources
3. Follow `genie/03_genie_configuration.md` to configure:
   - Title and description
   - Text instructions
   - SQL expressions (4)
   - Example SQL queries (8)
4. ✅ Test with the sample questions above

---

## Skills Demonstrated

| Skill | How it shows |
|---|---|
| **Dimensional data modeling** | Star schema: 2 dim tables + 2 fact tables |
| **ETL pipeline design** | Synthetic data → PySpark → Delta tables → Views |
| **Unity Catalog governance** | Catalog/database/table hierarchy, documented columns |
| **SQL views & metric layer** | Pre-joined, pre-aggregated views with business logic |
| **AI/BI tool configuration** | Genie tuned with domain-specific instructions and verified SQL |
| **Clinical domain knowledge** | Correct epidemiological framing (preterm definitions, antibody thresholds, timepoints) |
| **Equity-focused analytics** | Race/ethnicity and insurance-stratified outcome views |

---

## Background Context

This project is modeled after research in pediatric infectious diseases, specifically maternal RSV antibody studies relevant to RSV monoclonal antibody (mAb) programs and maternal vaccine trials. The synthetic data reflects realistic design features including:

- **Intentional preterm enrichment** (40% preterm) to power subgroup analyses
- **Longitudinal dropout** — increasing loss to follow-up at each timepoint
- **Comorbidity prevalence** based on realistic rates in an urban academic medical center cohort
- **Titer decay curve** — exponential waning consistent with published RSV antibody literature

---

## Author

**Komal Gopchandani, MBBS, MPH**
Data Analyst | Pediatric Infectious Diseases | Emory University School of Medicine
[LinkedIn](#) | [GitHub](#)

# Project: Refactor to General IV Analysis for Self-Insurance Status

## Goal
Clean up and refactor this codebase to focus on instrumental variables analysis for self-insurance status in a general context. Remove COVID-specific code and unnecessary files.

## Context
- Current codebase has COVID-specific DiD and IV analysis mixed with general IV code
- Primary IV is `linsurer_otstAMLR_LARGEGROUP` (insurer loss ratio)
- Treatment variable is now `self_insurance_status` (generalized from prior COVID-era DiD treatment)
- Need to generalize to study self-insurance status without COVID framing

## Sprints

### Sprint 1: Code Audit and Inventory
Deep dive into all R and Python scripts to categorize:
- Which files contain reusable IV/data prep logic
- Which files are COVID-specific and should be removed
- Which variables and functions are core vs COVID-specific
- Document the data pipeline and dependencies between scripts

Deliverables:
- Markdown report listing files to keep, modify, or delete
- Dependency graph of scripts

### Sprint 2: Identify Core Data Pipeline
Analyze data_prep.R, data_prep_ins_level_iv.R, and data_prep_pre_analysis.R to:
- Identify which data transformations are general vs COVID-specific
- Document the instrumental variables available
- Map out the panel data structure

Deliverables:
- List of data prep steps that should be preserved
- List of COVID-specific variables/transforms to remove

### Sprint 3: Clean Up Files
Based on the audit:
- Delete or archive COVID-specific analysis scripts
- Remove COVID-specific variables from data prep
- Update Functions_and_Options.R if needed
- Clean up llm_temp_code/ directory

Deliverables:
- Cleaned repository with only general IV analysis code
- Updated README for LLM.md

### Sprint 4: Refactor Core Scripts
Generalize the remaining scripts:
- Rename treatment variables to general terms (not COVID-specific)
- Update fixed effects to be general (remove year_month_state if COVID-specific)
- Ensure the IV identification strategy documentation is general

Deliverables:
- Refactored data_prep.R
- Refactored analysis script template

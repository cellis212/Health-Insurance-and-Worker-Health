<!-- CAM-BOT-HEADER-START -->
# Project Automation with cam-bot

Use `cam-bot` for multi-step tasks. **It may take a while—let it cook!**

## When to Use

**USE cam-bot for:** Multi-step features, data workflows, writing documents, refactoring

**DON'T use for:** Single-file edits, answering questions, running one command

---

## Quick Reference

```bash
# Create & run projects
cam-bot new plan.md                  # Create from markdown
cam-bot run projects/my-project.json # Execute (autonomous)
cam-bot status projects/my-project.json

# Code quality
cam-bot review project.json          # Find AI slop
cam-bot slop project.json            # Remove AI slop
cam-bot clean project.json           # Remove artifacts

# Writing
cam-bot write project.json "Write intro"
cam-bot edit project.json            # Editorial review
cam-bot copyedit project.json        # Final polish

# Skills
cam-bot skills list                  # List all skills
cam-bot skills info <name>           # Show skill details

# Utilities
cam-bot init                         # Scan project structure
cam-bot audit project.json --fix     # Fix data issues
cam-bot docs                         # Full documentation
```

---

## Sprint Statuses

| Status | Meaning |
|--------|---------|
| `pending` | Not started |
| `in_progress` | Developer working |
| `complete` | Passed QA |
| `blocked` | Needs human help |

---

## Sample Library (optional)

Put reusable example scripts in `samples/` at the cam-bot repo root (e.g., `samples/econ/spec_curves/`). When enabled, the Developer prompt can include a **“Sample Library (optional)”** section listing relevant files based on the sprint.

---

## Troubleshooting

```bash
# CLI not found? Check installation
claude --version

# Sprint stuck? Clear and retry
cam-bot update project.json sprint-001 --clear-blocked

# Data issues? Audit and fix
cam-bot audit project.json --fix
```

**More info:** `cam-bot docs` or `cam-bot <command> --help`
<!-- CAM-BOT-HEADER-END -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Econometric analysis of health insurance and worker health outcomes using difference-in-differences (DiD) and instrumental variables (IV) methods. Primary language is R with `fixest` for regressions; Python is used for data exploration.

## Commands

```bash
# Run R scripts (use Rscript, not R CMD)
Rscript script_name.R

# Activate renv environment (done automatically via .Rprofile)
source("renv/activate.R")

# Install/restore packages
Rscript -e "renv::restore()"
```

## Data Pipeline

Data lives in `../Data/` (outside this repository). The pipeline flows:

1. **data_prep.R** - Loads raw data from `../Data/raw_data/`, cleans and joins with IV data, performs matching to impute missing values, saves to `../Data/intermediate_data/prepared_data_for_analysis.RData`

2. **data_prep_pre_analysis.R** - Loads prepared data, creates event-time variables, bins, leave-one-out means for instruments, winsorizes outcomes, saves balanced panel to `data_balanced_pre_analysis.RData`

3. **Analysis scripts** (DiDs.R, try_ivs.R, Event Studies.R) - Load balanced data, run models, output tables/figures

## Architecture

- **Functions_and_Options.R** - Shared utilities and paths. Defines `figure_path`, `table_path` (point to Overleaf directories), helper functions (`add_stars`, `calculate_F_eff`, `variable_cap`, `sumStats`). Source this in analysis scripts.

- **Specification curves** - `spec_curve_run_models.R` runs models across combinations of options (fixed effects, winsorization, sample restrictions) in parallel. `spec_curve_print_curve.R` generates plots.

- **llm_temp_code/** - Directory for temporary Python exploration scripts and markdown summaries of data structures.

## Key Conventions

### R Code Style
- Use `fixest` for all regressions (OLS, 2SLS)
- Use `tidyverse` for data manipulation
- Clear workspace with `rm(list = ls())` at script start
- Add nolint comments at top/bottom of new scripts:
  ```r
  # nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.
  # ... code ...
  # nolint end
  ```

### Variable Names
Do not rename existing variables. Key variables include:
- `fully_ratio` - Insurance status (fully insured ratio)
- `self_insurance_status` - Treatment variable for IV analysis (equals `fully_ratio`)
- `linsurer_otstAMLR_LARGEGROUP` - Primary instrumental variable
- `ins_prsn_covered_eoy_cnt` - Firm size (persons covered)

### LaTeX Tables
Use manual `cat()` construction with this format:
```r
cat("
\\begin{tabular}{@{\\extracolsep{2pt}}lD{.}{.}{-3} D{.}{.}{-3}}
\\toprule
...
\\bottomrule
\\end{tabular}",
file = paste0(table_path, "filename.tex"))
```
Output tables to both `table_path` (Overleaf) and create a local copy.

### Documentation
Update "File Overviews" in `README for LLM.md` when creating or significantly modifying files.

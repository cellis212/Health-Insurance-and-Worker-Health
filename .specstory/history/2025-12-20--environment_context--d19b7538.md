# Codex Session — environment_context
> Converted from: `/Users/cameron/.codex/sessions/2025/12/20/rollout-2025-12-20T13-52-39-019b3d52-41aa-72b1-bb19-f7c0cc6323f2.jsonl`  
> Exported at: 2025-12-20 19:56  
> Working dir (guessed): `/Users/cameron/Dropbox/School/Papers/Health Insurance and Worker Health/Cam Code/projects/general-iv-self-insurance-refactor`

### You

<environment_context>
  <cwd>/Users/cameron/Dropbox/School/Papers/Health Insurance and Worker Health/Cam Code/projects/general-iv-self-insurance-refactor</cwd>
  <approval_policy>never</approval_policy>
  <sandbox_mode>workspace-write</sandbox_mode>
  <network_access>restricted</network_access>
  <shell>zsh</shell>
</environment_context>

### You

# Code Review Assignment

You are a Code Reviewer at The Firm. Your job is to clean up AI-generated code by removing
"slop" - the unnecessary verbosity, over-engineering, and filler that AI models tend to produce.

## Working Directory
projects/general-iv-self-insurance-refactor

## File Patterns to Review
- **/*.py
- **/*.js
- **/*.ts
- **/*.jsx
- **/*.tsx
- **/*.go
- **/*.rs
- **/*.java
- **/*.rb
- **/*.R
- **/*.r

## Patterns to Skip
- **/node_modules/**
- **/.venv/**
- **/venv/**
- **/__pycache__/**
- **/dist/**
- **/build/**
- **/*.min.js
- **/*.bundle.js

## Context
Just completed: consolidation: comprehensive review of all code

## Project Rules (consider when reviewing)
These are the explicit requirements for this project. Do NOT flag code as problematic
if it follows these rules. For example, if a rule says "use simulated data" or
"no external API calls", do not flag simulated data generation as a hidden fallback.

- Remove or archive COVID-specific analysis code; do not keep active COVID-era DiD framing in the core pipeline.
- Preserve and clearly document the primary instrument variable: linsurer_otstAMLR_LARGEGROUP (insurer loss ratio).
- Generalize the treatment variable currently named did_fully_2020 to a non-COVID self-insurance status name and update downstream code accordingly.
- Avoid speculative abstractions; only create artifacts that are used by subsequent sprints.
- Keep repository cleanup explicit and auditable via changelog-style documentation.

## AI Slop Patterns to Flag
- **excessive_comments**: Comments that state the obvious or repeat what the code already says
- **obvious_docstrings**: Docstrings like 'Initialize the class' or 'Get the value' that add no information
- **redundant_type_annotations**: Type hints that are obvious from context (e.g., `count: int = 0`)
- **over_abstraction**: Unnecessary wrapper classes, factories, or abstractions for simple operations
- **unnecessary_error_handling**: Try/except blocks for errors that can't happen or overly defensive code
- **verbose_variable_names**: Names like `string_to_be_processed` instead of `text` or `input_data_list` instead of `items`
- **premature_optimization**: Caching, pooling, or optimization for code that isn't a bottleneck
- **dead_code**: Unused imports, unreachable code, or functions that are never called
- **commented_out_code**: Old code left in comments instead of being deleted
- **ai_placeholder_comments**: Comments like '# TODO: implement', '# Add error handling here', '# Your code here'
- **hidden_fallbacks**: CRITICAL: Silent fallbacks that hide failures - generating fake/simulated data when real data is missing, returning default values instead of raising errors, catching exceptions and continuing silently, or any code that masks what is actually running
- **unused_files**: STRUCTURAL: Files or modules created but never imported or used anywhere in the codebase

## CRITICAL: Hidden Fallback Detection

**This is the MOST IMPORTANT thing to detect.** Hidden fallbacks can cause catastrophic failures in research and production systems because they make code appear to work when it's actually running on fake or incorrect data.

**YOU MUST FLAG any code that:**

1. **Generates fake/simulated data when real data is missing**
   - `if data is None: data = generate_random_sample()`
   - `except FileNotFoundError: return create_synthetic_data()`
   - Any simulation, sampling, or data generation used as a fallback

2. **Silently substitutes default values instead of failing**
   - `return default_value if result is None else result`
   - `config.get('key', some_hardcoded_value)` where missing config should error
   - Any "graceful degradation" that hides the fact that required data is missing

3. **Catches exceptions and continues without proper handling**
   - `except Exception: pass`
   - `except: return []` (returns empty instead of propagating error)
   - Any try/except that swallows errors the caller should know about

4. **Makes it unclear what code path is actually executing**
   - Multiple fallback layers that obscure the actual data source
   - Conditional logic that silently switches between real and fake implementations
   - "Demo mode" or "test mode" flags that can accidentally run in production

**Example of DANGEROUS hidden fallback:**
```python
def load_patient_data(patient_id):
    try:
        return database.query(patient_id)
    except DatabaseError:
        # DANGEROUS: Returns fake data instead of failing!
        return {"age": 45, "weight": 70, "symptoms": []}
```

**What it should be:**
```python
def load_patient_data(patient_id):
    return database.query(patient_id)  # Let errors propagate
```

**Flag these with pattern_type: hidden_fallbacks and mark them as HIGH PRIORITY.**

## STRUCTURAL: Unused File Detection

**Detect files that were created but are never used.** This is a structural problem that wastes space and causes confusion.

**How to detect unused files:**

1. **List all source files** in the project (matching code_review_file_patterns)
2. **For each file**, check if it is:
   - Imported by any other file (`import X`, `from X import Y`)
   - Referenced in configuration (setup.py, pyproject.toml entry points)
   - Used as a script entry point (__main__.py, cli.py referenced in console_scripts)
   - Part of a __init__.py export chain that IS used

3. **Flag files that have NO references** as `unused_files` pattern

**Example of unused file:**
```
# src/models.py exists with class definitions
# But NO file does: import models, from models import X, from .models import X
# And it's not in __init__.py exports that are actually used
# → Flag as unused_files
```

**Report unused files with:**
```yaml
- file: src/models.py
  line: 1
  pattern: unused_files
  code: |
    (entire file - 45 lines)
  recommendation: Delete file - not imported or referenced anywhere
```

**What is NOT an unused file:**
- Entry points defined in pyproject.toml/setup.py
- Files imported transitively through __init__.py
- Test files (test_*.py, *_test.py)
- Configuration files

## What Good Code Looks Like (for reference)
- Comments only where logic isn't self-evident
- Variable names that are concise but clear (prefer `user` over `user_object_instance`)
- No docstrings for obvious methods (getters, setters, simple operations)
- Error handling only at boundaries (user input, external APIs), not internal code
- Direct implementation over abstraction when there's only one use case
- Trust the type system; don't annotate obvious types
- Delete code rather than comment it out
- Three similar lines is often better than a premature abstraction

## What to Preserve (don't flag these)
- Meaningful comments that explain WHY (not what)
- Docstrings for public APIs with non-obvious behavior
- Type annotations that genuinely help (complex return types, generics)
- Error handling at system boundaries
- Abstractions that serve multiple concrete use cases

## Instructions
1. Review the code files (prioritize recently modified files if provided)
2. Identify AI slop patterns
3. FLAG the specific locations - DO NOT modify any files
4. For each finding, provide the exact file, line number(s), and what should be removed
5. A separate process will test whether removal breaks anything

## IMPORTANT: Do NOT edit any files. Only report findings.

## Output Format
Report your findings in this format:

FINDINGS:
- file: path/to/file1.py
  line: 42
  pattern: excessive_comments
  code: |
    # This function adds two numbers together and returns the result
  recommendation: Remove comment - the function name `add` is self-explanatory

- file: path/to/file2.py
  lines: 15-28
  pattern: over_abstraction
  code: |
    class StringProcessor:
        def process(self, s):
            return s.strip()
  recommendation: Replace class with direct `.strip()` call at usage site

- file: path/to/utils.py
  line: 7
  pattern: obvious_docstrings
  code: |
    def get_name(self):
        """Get the name."""
        return self.name
  recommendation: Remove docstring

SUMMARY:
- Files reviewed: [number]
- Total findings: [number]
- By pattern:
  - excessive_comments: [count]
  - obvious_docstrings: [count]
  - etc.

ISSUES_FOUND:
- Any code smells or problems that need human attention beyond slop removal

If you find code that seems intentionally verbose or you're unsure whether it's slop,
say "NEEDS_HUMAN_REVIEW:" followed by the reason.

### Shell

```bash
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Shell

```bash
$ rg --files --hidden --follow | rg -e '\.(py|js|ts|jsx|tsx|go|rs|java|rb|R|r)$' | rg -v '(^|/)(node_modules|\.venv|venv|__pycache__|dist|build)(/|$)'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
analysis/iv_analysis_template.R
```

</details>

### Shell

```bash
$ nl -ba analysis/iv_analysis_template.R | sed -n '1,200p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# IV Analysis Template: Self-Insurance Status
     2	# Instrument: Insurer loss ratio (linsurer_otstAMLR_LARGEGROUP)
     3	# Treatment: self_insurance_status (continuous measure of fully insured ratio)
     4	
     5	library(tidyverse)
     6	library(fixest)
     7	
     8	project_dir <- "../Data"
     9	interm_dir <- file.path(project_dir, "intermediate_data")
    10	source("Functions_and_Options.R")
    11	
    12	load(file.path(interm_dir, "data_balanced_pre_analysis.RData"))
    13	
    14	outcome_var <- "raw_visitor_counts"
    15	treatment_var <- "self_insurance_status"
    16	instrument_var <- "linsurer_otstAMLR_LARGEGROUP"
    17	
    18	# Fixed effects: firm + time (year-month crossed with geography/industry)
    19	fe_baseline <- "ein + year_month"
    20	fe_geography <- "ein + year_month + czone^year_month"
    21	fe_industry <- "ein + year_month + two_digit^year_month"
    22	fe_full <- "ein + year_month + czone^year_month + two_digit^year_month"
    23	
    24	cluster_var <- "ein"
    25	
    26	# Sample Filters
    27	analysis_data <- data_balanced %>%
    28	  filter(
    29	    !is.na(.data[[outcome_var]]),
    30	    !is.na(.data[[treatment_var]]),
    31	    !is.na(.data[[instrument_var]])
    32	  )
    33	
    34	cat("Sample size after filtering:", nrow(analysis_data), "\n")
    35	cat("Number of firms:", n_distinct(analysis_data$ein), "\n")
    36	cat("Date range:", min(analysis_data$year), "-", max(analysis_data$year), "\n")
    37	
    38	# First Stage Diagnostics
    39	first_stage <- feols(
    40	  as.formula(paste(treatment_var, "~", instrument_var, "|", fe_baseline)),
    41	  data = analysis_data,
    42	  cluster = cluster_var
    43	)
    44	
    45	cat("\n=== First Stage ===\n")
    46	summary(first_stage)
    47	
    48	# IV Estimation: Baseline
    49	iv_baseline <- feols(
    50	  as.formula(paste(
    51	    outcome_var, "~ 1 |", fe_baseline, "|",
    52	    treatment_var, "~", instrument_var
    53	  )),
    54	  data = analysis_data,
    55	  cluster = cluster_var
    56	)
    57	
    58	cat("\n=== IV: Baseline Fixed Effects ===\n")
    59	summary(iv_baseline)
    60	cat("First-stage F:", fitstat(iv_baseline, "ivwald")$ivwald1$stat, "\n")
    61	
    62	# IV Estimation: With Geography FE
    63	iv_geo <- feols(
    64	  as.formula(paste(
    65	    outcome_var, "~ 1 |", fe_geography, "|",
    66	    treatment_var, "~", instrument_var
    67	  )),
    68	  data = analysis_data,
    69	  cluster = cluster_var
    70	)
    71	
    72	cat("\n=== IV: Geography Fixed Effects ===\n")
    73	summary(iv_geo)
    74	cat("First-stage F:", fitstat(iv_geo, "ivwald")$ivwald1$stat, "\n")
    75	
    76	# IV Estimation: With Industry FE
    77	iv_ind <- feols(
    78	  as.formula(paste(
    79	    outcome_var, "~ 1 |", fe_industry, "|",
    80	    treatment_var, "~", instrument_var
    81	  )),
    82	  data = analysis_data,
    83	  cluster = cluster_var
    84	)
    85	
    86	cat("\n=== IV: Industry Fixed Effects ===\n")
    87	summary(iv_ind)
    88	cat("First-stage F:", fitstat(iv_ind, "ivwald")$ivwald1$stat, "\n")
    89	
    90	# IV Estimation: Full FE
    91	iv_full <- feols(
    92	  as.formula(paste(
    93	    outcome_var, "~ 1 |", fe_full, "|",
    94	    treatment_var, "~", instrument_var
    95	  )),
    96	  data = analysis_data,
    97	  cluster = cluster_var
    98	)
    99	
   100	cat("\n=== IV: Full Fixed Effects ===\n")
   101	summary(iv_full)
   102	cat("First-stage F:", fitstat(iv_full, "ivwald")$ivwald1$stat, "\n")
   103	
   104	# Results Table
   105	models <- list(
   106	  "Baseline" = iv_baseline,
   107	  "Geography" = iv_geo,
   108	  "Industry" = iv_ind,
   109	  "Full" = iv_full
   110	)
   111	
   112	etable(models,
   113	  se.below = TRUE,
   114	  fitstat = c("n", "ivwald"),
   115	  dict = c(
   116	    self_insurance_status = "Self-Insurance Status",
   117	    raw_visitor_counts = "Visitor Counts"
   118	  )
   119	)
```

</details>

### Shell

```bash
$ nl -ba analysis/iv_analysis_template.R | sed -n '200,400p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
```

</details>

### Shell

```bash
$ ls -la
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
total 24
drwxr-xr-x@ 7 cameron  staff   224 Dec 20 13:50 .
drwxr-xr-x@ 4 cameron  staff   128 Dec 20 11:42 ..
drwxr-xr-x@ 3 cameron  staff    96 Dec 20 13:51 analysis
-rw-r--r--@ 1 cameron  staff  1838 Dec 20 11:42 CLAUDE.md
drwxr-xr-x@ 7 cameron  staff   224 Dec 20 13:50 docs
-rw-------@ 1 cameron  staff   732 Dec 20 13:50 LLM.md
-rw-------@ 1 cameron  staff   901 Dec 20 13:50 README.md
```

</details>

### Shell

```bash
$ find . -maxdepth 4 -type f | sed 's|^\./||'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
analysis/iv_analysis_template.R
docs/cleanup-changelog.md
docs/migration-notes.md
docs/iv-identification.md
docs/audit-report.md
docs/core-pipeline.md
README.md
LLM.md
CLAUDE.md
```

</details>

### Shell

```bash
$ rg -n "iv_analysis_template" -S .
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
./LLM.md:9:**`analysis/iv_analysis_template.R`** - Start here for IV estimation.
```

</details>

### Shell

```bash
$ rg --files -g'Functions_and_Options.R' -S .
```

<details><summary>stdout</summary>

```text
Exit code: 1
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
```

</details>

### Shell

```bash
$ rg -n "Functions_and_Options\.R" -S .
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
./docs/cleanup-changelog.md:39:| Functions_and_Options.R | Renamed Overleaf paths from "Covid Moral Hazard in ESI" to "Self-Insurance IV Analysis" |
./analysis/iv_analysis_template.R:10:source("Functions_and_Options.R")
```

</details>

### Shell

```bash
$ nl -ba docs/cleanup-changelog.md | sed -n '1,120p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# Cleanup Changelog
     2	
     3	Records all archive and delete actions performed during the COVID-specific code removal.
     4	
     5	## Archived to archive/covid/
     6	
     7	| File | Source Path | Reason |
     8	|------|-------------|--------|
     9	| DiDs.R | ./DiDs.R | COVID-era difference-in-differences analysis script |
    10	| DiDs - interact.R | ./DiDs - interact.R | COVID DiD with interaction terms |
    11	| Event Studies.R | ./Event Studies.R | Event study relative to March 2020 COVID onset |
    12	| spec_curve_run_models.R | ./spec_curve_run_models.R | Specification curve for COVID DiD models |
    13	| spec_curve_print_curve.R | ./spec_curve_print_curve.R | Visualization for COVID specification curves |
    14	| try_ivs.R | ./try_ivs.R | IV analysis with COVID-specific treatment variables |
    15	| explore_remote_work.py | ./explore_remote_work.py | PPP/COVID remote work exploration |
    16	| analysis.R | ./analysis.R | COVID-era IV analysis with post_covid variable |
    17	| data_exploration.R | ./data_exploration.R | Data exploration with COVID interaction terms |
    18	
    19	## Deleted
    20	
    21	| File | Source Path | Reason |
    22	|------|-------------|--------|
    23	| explore_ppp_data.py | llm_temp_code/explore_ppp_data.py | PPP data exploration script (COVID-related, temporary) |
    24	| data_summary.md | llm_temp_code/data_summary.md | Data summary with COVID-specific variable references |
    25	
    26	## Created
    27	
    28	| File | Path | Purpose |
    29	|------|------|---------|
    30	| README.md | llm_temp_code/README.md | Documents purpose of llm_temp_code/ directory |
    31	
    32	## Modified (COVID Variables Removed)
    33	
    34	| File | Changes |
    35	|------|---------|
    36	| data_prep.R | Removed `post_covid` variable creation and `did_fully`, `did_fully_2020` DiD variables |
    37	| data_prep_pre_analysis.R | Replaced `did_fully_2020` with `fully_ratio` as treatment variable; removed `:post_covid` from IV specification |
    38	| data_prep_ins_level_iv.R | Removed `post_covid` variable creation and `did_fully`, `did_fully_2020` DiD variables |
    39	| Functions_and_Options.R | Renamed Overleaf paths from "Covid Moral Hazard in ESI" to "Self-Insurance IV Analysis" |
    40	| load_acs_data.R | Removed "pre-COVID baseline" comment from year 2019 data fetch |
    41	
    42	## Sprint 4: Data Prep Refactoring
    43	
    44	| File | Changes |
    45	|------|---------|
    46	| data_prep.R | Removed `ins_status_2020_jan`, `ins_status_2018_jan`, `iv_var_2019`, `iv_var_2018`, `iv_var_pre_2020` variables |
    47	| data_prep_ins_level_iv.R | Removed `ins_status_2020_jan`, `ins_status_2018_jan`, `iv_var_2019`, `iv_var_2018`, `iv_var_pre_2020`, `iv_var_increase` variables |
    48	| data_prep_pre_analysis.R | Removed `dep_var_pre`; renamed `treat` to `self_insurance_status`; replaced hardcoded `year == 2020` with configurable `base_year` |
    49	| CLAUDE.md | Updated variable documentation to reference `self_insurance_status` instead of `did_fully_2020` |
    50	| cleanup_plan.md | Updated to reflect completed treatment variable rename |
    51	
    52	## Summary
    53	
    54	- 9 COVID-specific analysis scripts archived to archive/covid/
    55	- 2 temporary files deleted from llm_temp_code/
    56	- llm_temp_code/ now contains only README.md explaining its purpose
    57	- 5 pipeline/infrastructure scripts modified to remove COVID-specific references (Sprint 3)
    58	- 5 additional files modified to complete COVID variable removal and treatment variable rename (Sprint 4)
    59	- No COVID references remain in active analysis/pipeline code (verified via `rg -i "covid"` outside archive/)
    60	- Treatment variable renamed: `did_fully_2020` → `self_insurance_status`
    61	- Primary IV preserved: `linsurer_otstAMLR_LARGEGROUP`
```

</details>

### Shell

```bash
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Shell

```bash
$ rg -n "TODO|FIXME|tryCatch\(|set\.seed\(|runif\(|rnorm\(|sample\(" analysis/iv_analysis_template.R
```

<details><summary>stdout</summary>

```text
Exit code: 1
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
```

</details>

### Shell

```bash
$ rg -n "file\.exists\(|if\s*\(.+is\.na\(|\%\|\%|try\(" analysis/iv_analysis_template.R
```

<details><summary>stdout</summary>

```text
Exit code: 1
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
```

</details>

### Shell

```bash
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Shell

```bash
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Shell

```bash
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Shell

```bash
$ nl -ba LLM.md | sed -n '1,120p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# LLM Context for Self-Insurance IV Analysis
     2	
     3	## Project Summary
     4	
     5	IV analysis of employer self-insurance effects on worker health. Uses insurer loss ratios as an instrument for self-insurance status.
     6	
     7	## Canonical Entrypoint
     8	
     9	**`analysis/iv_analysis_template.R`** - Start here for IV estimation.
    10	
    11	## Key Variables
    12	
    13	- **Treatment**: `self_insurance_status` (continuous 0-1, formerly `fully_ratio`)
    14	- **Instrument**: `linsurer_otstAMLR_LARGEGROUP` (insurer loss ratio)
    15	- **Panel**: firm (`ein`) × month (`year`, `month`)
    16	
    17	## Fixed Effects
    18	
    19	| FE | Purpose |
    20	|----|---------|
    21	| `ein` | Firm heterogeneity |
    22	| `year_month` | Time shocks |
    23	| `czone^year_month` | Local labor market trends |
    24	| `two_digit^year_month` | Industry trends |
    25
```

</details>

### Shell

```bash
$ nl -ba README.md | sed -n '1,200p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# Self-Insurance IV Analysis
     2	
     3	Instrumental variables analysis of employer self-insurance status effects on worker health outcomes.
     4	
     5	## Project Goal
     6	
     7	Estimate the causal effect of employer self-insurance decisions on worker health using insurer loss ratios as an instrument. The insurer loss ratio (`linsurer_otstAMLR_LARGEGROUP`) provides exogenous variation in insurance costs that affects employer self-insurance choices.
     8	
     9	## Key Variables
    10	
    11	| Variable | Description |
    12	|----------|-------------|
    13	| `self_insurance_status` | Treatment: fully insured ratio (0-1 continuous) |
    14	| `linsurer_otstAMLR_LARGEGROUP` | Instrument: insurer loss ratio for large group market |
    15	| `ein` | Panel unit: employer identification number |
    16	| `year`, `month` | Time index |
    17	
    18	## Documentation
    19	
    20	- `docs/iv-identification.md` - Identification strategy and assumptions
    21	- `docs/core-pipeline.md` - Data pipeline specification
```

</details>

### Shell

```bash
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Codex

FINDINGS:
- file: analysis/iv_analysis_template.R
  line: 10
  pattern: dead_code
  code: |
    source("Functions_and_Options.R")
  recommendation: Remove this `source()` call (or vendor the missing `Functions_and_Options.R` into the repo); as written, the script will error immediately in a clean checkout.

SUMMARY:
- Files reviewed: 1
- Total findings: 1
- By pattern:
  - dead_code: 1
  - hidden_fallbacks: 0
  - unused_files: 0

ISSUES_FOUND:
- `analysis/iv_analysis_template.R` also hard-depends on `../Data/intermediate_data/data_balanced_pre_analysis.RData`; if this repo is meant to be runnable standalone, the data location/requirements should be documented (otherwise the “canonical entrypoint” won’t run).

---

**Models seen:** gpt-5.2

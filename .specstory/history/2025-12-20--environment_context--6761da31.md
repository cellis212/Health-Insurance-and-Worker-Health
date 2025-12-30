# Codex Session — environment_context
> Converted from: `/Users/cameron/.codex/sessions/2025/12/20/rollout-2025-12-20T11-59-51-019b3cea-fb08-7b83-bf65-aa760e92c4d4.jsonl`  
> Exported at: 2025-12-20 18:07  
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

## Files Modified This Sprint (prioritize these)
- docs/core-pipeline.md
- data_prep.R
- data_prep_ins_level_iv.R
- data_prep_pre_analysis.R

## Context
Just completed: Sprint sprint-002: Specify core pipeline and variables

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
$ rg --files -g'*.py' -g'*.js' -g'*.ts' -g'*.jsx' -g'*.tsx' -g'*.go' -g'*.rs' -g'*.java' -g'*.rb' -g'*.R' -g'*.r' -g'!node_modules/**' -g'!.venv/**' -g'!venv/**' -g'!__pycache__/**' -g'!dist/**' -g'!build/**' -g'!*.min.js' -g'!*.bundle.js'
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
$ echo hi
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
hi
```

</details>

### Shell

```bash
$ which rg && rg --version
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
/opt/homebrew/bin/rg
ripgrep 14.1.1

features:+pcre2
simd(compile):+NEON
simd(runtime):+NEON

PCRE2 10.43 is available (JIT is available)
```

</details>

### Shell

```bash
$ ls
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
CLAUDE.md
docs
```

</details>

### Shell

```bash
$ find . -maxdepth 4 -type f
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
./docs/dependency-graph.md
./docs/audit-report.md
./docs/core-pipeline.md
./CLAUDE.md
```

</details>

### Shell

```bash
$ rg --files
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
CLAUDE.md
docs/core-pipeline.md
docs/audit-report.md
docs/dependency-graph.md
```

</details>

### Shell

```bash
$ nl -ba docs/core-pipeline.md | sed -n '1,200p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# Core Pipeline Specification
     2	
     3	This document specifies the core data pipeline for IV analysis of self-insurance status, separating general logic from COVID-specific transformations.
     4	
     5	## Panel Structure
     6	
     7	| Element | Variable | Description |
     8	|---------|----------|-------------|
     9	| Unit | `ein` | Employer Identification Number (firm-level) |
    10	| Time Index | `year`, `month` | Monthly panel |
    11	| Geography | `czone` | Commuting zone |
    12	| Geography (alt) | `fips`, `state_abbr` | County/state identifiers |
    13	| Insurer | `naic_code` | NAIC insurer code |
    14	| Industry | `business_code` | Industry classification |
    15	| Firm Size | `ins_prsn_covered_eoy_cnt` | Persons covered at end of year |
    16	
    17	### Key Identifiers
    18	
    19	- `ein`: Primary unit identifier (firm)
    20	- `year` + `month`: Time dimensions (creates `year_month` factor)
    21	- `naic_code`: Links firms to insurers for IV construction
    22	- `czone`: Commuting zone for geographic fixed effects
    23	- `first_two_digits_business_code`: Industry classification (derived from `business_code`)
    24	
    25	## Instruments
    26	
    27	### Primary Instrument
    28	
    29	**`linsurer_otstAMLR_LARGEGROUP`** - Insurer loss ratio for large group market
    30	
    31	- Source: `healthpremium_iv_at.csv`
    32	- Constructed at insurer-year level
    33	- Joined to firm data via `ein` and `year`
    34	- Missing values imputed via matching on `ins_prsn_covered_eoy_cnt` within `year + month + industry + czone` cells
    35	
    36	This instrument exploits variation in insurer financial health (loss ratios) that affects employer insurance costs but is plausibly exogenous to individual firm health outcomes.
    37	
    38	### Alternative Instruments
    39	
    40	| Variable | Script | Description |
    41	|----------|--------|-------------|
    42	| `iv_var_1`, `iv_var_2` | data_prep_ins_level_iv.R | Leave-one-out retention costs per person by insurer-year-month |
    43	| `e_centered` | data_prep_pre_analysis.R | Leave-one-out mean of `fully_ratio` within czone-state-size cells |
    44	
    45	## Treatment and Outcomes
    46	
    47	### Generalized Treatment Variable
    48	
    49	**Rename:** `did_fully_2020` → `self_insurance_status`
    50	
    51	The current `did_fully_2020` is defined as:
    52	```r
    53	did_fully_2020 = ins_status_2020_jan * post_covid
    54	```
    55	
    56	This is COVID-specific (freezes insurance status at January 2020 and interacts with post-COVID indicator). The generalized treatment should be:
    57	
    58	**`self_insurance_status`** = `fully_ratio` (continuous) or a binary/categorical measure of self-insurance
    59	
    60	For IV analysis without event-study structure:
    61	- Use `fully_ratio` directly as the endogenous regressor
    62	- Instrument with `linsurer_otstAMLR_LARGEGROUP`
    63	
    64	For event-study or DiD structure with arbitrary treatment timing:
    65	- Define treatment status at a configurable base period
    66	- Create post-treatment indicator relative to arbitrary date (not hardcoded March 2020)
    67	
    68	### Core Insurance Variables (Keep)
    69	
    70	| Variable | Description |
    71	|----------|-------------|
    72	| `fully_ratio` | Share of plan that is fully insured (continuous 0-1) |
    73	| `self_ratio` | Share of plan that is self-insured (continuous 0-1) |
    74	| `self_d` | Binary self-insured indicator |
    75	| `mixed_d` | Binary mixed insurance indicator |
    76	
    77	### Outcome Variables
    78	
    79	Outcome variables are loaded from the main panel (`step_13_panel_for_ols_iv_reg_new.csv`) and include workplace visit counts and other measures. These are not COVID-specific.
    80	
    81	## COVID-Specific Removals
    82	
    83	### Variables to Remove
    84	
    85	| Variable | Script | Reason |
    86	|----------|--------|--------|
    87	| `post_covid` | data_prep.R, data_prep_ins_level_iv.R | Hardcoded to March 2020 |
    88	| `did_fully_2020` | data_prep.R, data_prep_ins_level_iv.R | COVID-era DiD treatment |
    89	| `ins_status_2020_jan` | data_prep.R, data_prep_ins_level_iv.R | Insurance status frozen at COVID date |
    90	| `ins_status_2018_jan` | data_prep.R, data_prep_ins_level_iv.R | Pre-COVID reference period |
    91	| `iv_var_2019` | data_prep.R, data_prep_ins_level_iv.R | Year-specific IV average |
    92	| `iv_var_2018` | data_prep.R, data_prep_ins_level_iv.R | Year-specific IV average |
    93	| `iv_var_pre_2020` | data_prep.R, data_prep_ins_level_iv.R | Pre-2020 IV average |
    94	| `iv_var_increase` | data_prep_ins_level_iv.R | 2019-2018 IV change |
    95	| `treat` | data_prep_pre_analysis.R | Alias for `did_fully_2020` |
    96	| `dep_var_pre` | data_prep_pre_analysis.R | Pre-COVID outcome mean |
    97	
    98	### Hardcoded Dates to Remove
    99	
   100	| Code Pattern | Script | Replacement |
   101	|--------------|--------|-------------|
   102	| `year == 2020 & month >= 3` | data_prep.R:100 | Configurable treatment date |
   103	| `year > 2020` | data_prep.R:100 | Configurable post-period |
   104	| `year == 2020 & month == 1` | data_prep.R:87-88 | Configurable base period |
   105	| `year == 2018 & month == 1` | data_prep.R:88 | Remove entirely |
   106	| `year < 2020` | data_prep.R:139 | Configurable pre-period |
   107	| `year == 2020 & month < 3` | data_prep_pre_analysis.R:90 | Remove event-time logic |
   108	
   109	### Script-by-Script Changes
   110	
   111	#### data_prep.R
   112	
   113	**Keep:**
   114	- Raw data loading (lines 17-48)
   115	- IV data join (lines 56-73)
   116	- State filtering (lines 77-78)
   117	- `fully_ratio` filter (line 81)
   118	- NAIC code cleaning (lines 117-121)
   119	- Matching for missing IV imputation (lines 123-204)
   120	- Backfill czone logic (lines 153-165)
   121	- Business code extraction (lines 168-173)
   122	
   123	**Remove:**
   124	- Lines 83-90: `ins_status_2020_jan`, `ins_status_2018_jan` creation
   125	- Lines 98-100: `post_covid` creation
   126	- Lines 102-107: `did_fully`, `did_fully_2020` creation
   127	- Lines 132-141: `iv_var_2019`, `iv_var_2018`, `iv_var_pre_2020` creation
   128	
   129	#### data_prep_ins_level_iv.R
   130	
   131	**Keep:**
   132	- Raw data loading (lines 17-45)
   133	- IV data join (lines 54-70)
   134	- State/insurance filtering (lines 73-76)
   135	- NAIC matching (lines 78-112)
   136	- Leave-one-out IV construction (lines 116-145)
   137	- Firm size binning (lines 186-203)
   138	
   139	**Remove:**
   140	- Lines 147-154: `ins_status_2020_jan`, `ins_status_2018_jan` creation
   141	- Lines 156-165: `iv_var_2019`, `iv_var_2018`, `iv_var_pre_2020`, `iv_var_increase` creation
   142	- Lines 169-171: `post_covid` creation
   143	- Lines 174-179: `did_fully`, `did_fully_2020` creation
   144	
   145	#### data_prep_pre_analysis.R
   146	
   147	**Keep:**
   148	- Data loading (lines 22-23)
   149	- Mixed plan filter (line 28)
   150	- Leave-one-out IV construction `e_centered` (lines 61-77)
   151	- Winsorization logic (lines 103-111)
   152	
   153	**Remove:**
   154	- Lines 42-58: IV binning based on January 2020
   155	- Lines 84-92: `dep_var_pre` based on pre-COVID period
   156	- Lines 96-100: `treat = did_fully_2020` assignment
   157	- Lines 118-139: COVID-era IV regression examples
   158	
   159	**Generalize:**
   160	- The `e_centered` leave-one-out construction (lines 61-77) currently filters to `year == 2020 & month == 1`. This should accept a configurable base period parameter.
   161	
   162	## Summary
   163	
   164	The core pipeline preserves:
   165	1. Panel structure: firm (ein) × month (year-month)
   166	2. Primary IV: `linsurer_otstAMLR_LARGEGROUP`
   167	3. Treatment measure: `fully_ratio` (endogenous) instrumented by insurer loss ratio
   168	4. Matching/imputation logic for missing instrument values
   169	5. Geographic and industry fixed effects structure
   170	
   171	The refactored pipeline removes all references to COVID-19 timing (March 2020) and replaces the COVID-specific `did_fully_2020` treatment with a general `self_insurance_status` measure suitable for cross-sectional IV or arbitrary event-study designs.
```

</details>

### Shell

```bash
$ nl -ba docs/audit-report.md | sed -n '1,260p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# Code Audit Report
     2	
     3	This document inventories all R and Python scripts in the repository and classifies each file for the refactoring effort to remove COVID-specific code and focus on general IV analysis of self-insurance status.
     4	
     5	## File Inventory
     6	
     7	| Path | Action | Reason |
     8	|------|--------|--------|
     9	| data_prep.R | **Modify** | Core data preparation script. Contains COVID-specific variables (`post_covid`, `did_fully_2020`, `ins_status_2020_jan`) that need generalization. Preserves primary IV (`linsurer_otstAMLR_LARGEGROUP`). |
    10	| data_prep_ins_level_iv.R | **Modify** | Alternative data prep with insurance-level IV construction. Contains COVID-specific variables (`post_covid`, `did_fully_2020`). Core IV logic should be preserved. |
    11	| data_prep_pre_analysis.R | **Modify** | Pre-analysis data preparation. Contains COVID-specific references (event time relative to March 2020, `did_fully_2020`). Needs generalization of event time variables. |
    12	| Functions_and_Options.R | **Keep** | Shared utility functions and paths. Core infrastructure with no COVID-specific code. Contains `calculate_F_eff`, `variable_cap`, `sumStats`. |
    13	| DiDs.R | **Archive** | COVID-era DiD analysis script. Directly tied to COVID treatment timing (March 2020). Replace with general IV analysis template. |
    14	| DiDs - interact.R | **Archive** | COVID-era DiD with heterogeneous treatment effects. Uses `xvar_2020`, `post_covid` extensively. COVID-specific framing throughout. |
    15	| Event Studies.R | **Archive** | Event study plots centered on COVID treatment date (March 2020). Uses `event_time_fac` tied to COVID timing. |
    16	| try_ivs.R | **Archive** | Specification search script for COVID-era DiD-IV. Uses `did_fully_2020` and COVID-specific sample restrictions. |
    17	| spec_curve_run_models.R | **Archive** | Specification curve analysis for COVID DiD. Treatment variable is `did_fully_2020`. |
    18	| spec_curve_print_curve.R | **Archive** | Visualization of specification curves. Depends on COVID-specific spec_curve_run_models.R output. |
    19	| analysis.R | **Archive** | Ad-hoc analysis script using COVID-era variables (`did_fully_2020`, `post_covid`). Exploratory rather than core pipeline. |
    20	| Visualization.R | **Keep** | Generic visualization utilities. No COVID-specific code. Creates propensity score histograms. |
    21	| data_exploration.R | **Modify** | Creates centered IV variables and event study data. Contains COVID timing references but core IV construction logic is reusable. |
    22	| Test_Control_Function.r | **Keep** | Simulation script for control function approach. Educational/testing only. No COVID-specific code. |
    23	| install_packages.R | **Keep** | Package installation helper. Infrastructure only. |
    24	| load_acs_data.R | **Keep** | ACS demographic data loader. Generic data ingestion. |
    25	| collect_reg_results.py | **Archive** | Collects bootstrap regression results. Tied to deprecated result structure. |
    26	| llm_temp_code/explore_ppp_data.py | **Archive** | PPP exposure data exploration. COVID-specific (PPP was pandemic relief). |
    27	| explore_remote_work.py | **Keep** | Creates remote work shares by industry. Useful covariate not COVID-specific. |
    28	
    29	## Core vs COVID-Specific Components
    30	
    31	### Core Components (Keep/Modify)
    32	
    33	These components form the data pipeline and should be preserved:
    34	
    35	**Variables:**
    36	- `linsurer_otstAMLR_LARGEGROUP` - Primary instrumental variable (insurer loss ratio)
    37	- `fully_ratio` / `self_ratio` - Insurance status measures
    38	- `ins_prsn_covered_eoy_cnt` - Firm size (persons covered)
    39	- `naic_code` - Insurer identifier
    40	- `czone` - Commuting zone geography
    41	- `ein` - Employer identification
    42	- `business_code` - Industry classification
    43	
    44	**Functions:**
    45	- `calculate_F_eff()` - Effective F-statistic calculation
    46	- `variable_cap()` - Winsorization utility
    47	- `sumStats()` - Summary statistics helper
    48	- Matching/imputation logic for missing IV values
    49	
    50	### COVID-Specific Items
    51	
    52	These items are tied to COVID-19 pandemic analysis and should be removed or generalized:
    53	
    54	**Variables to Remove/Generalize:**
    55	- `did_fully_2020` - DiD treatment variable (ins_status_2020_jan × post_covid). **Must be generalized** to a non-COVID self-insurance status name.
    56	- `post_covid` - Post-treatment indicator (year > 2020 or month >= 3 in 2020)
    57	- `ins_status_2020_jan` - Insurance status frozen at January 2020
    58	- `ins_status_2018_jan` - Insurance status frozen at January 2018
    59	- `iv_var_pre_2020` - Pre-2020 IV averages
    60	- `iv_var_2019`, `iv_var_2018` - Year-specific IV values
    61	- `xvar_2020` - Treatment variable in interaction scripts
    62	- `event_time` / `event_time_fac` - Event time relative to March 2020
    63	
    64	**Scripts to Archive:**
    65	- All DiD analysis scripts (DiDs.R, DiDs - interact.R)
    66	- Event study scripts (Event Studies.R)
    67	- Specification curve scripts (spec_curve_*.R)
    68	- COVID-specific try_ivs.R
    69	- PPP-related Python scripts
    70	
    71	**Hardcoded Dates:**
    72	- `year == 2020 & month >= 3` - COVID treatment start
    73	- `treatment_date = as.Date("2020-03-01")` - Event study reference
    74	- `year < 2020` - Pre-period definitions
    75	
    76	## Recommended Actions by Priority
    77	
    78	### Phase 1: Preserve Core Pipeline
    79	1. Document current data flow from raw data to analysis-ready datasets
    80	2. Identify the minimal set of scripts needed for IV analysis
    81	3. Extract reusable IV construction logic from data_prep.R
    82	
    83	### Phase 2: Generalize Treatment Variables
    84	1. Rename `did_fully_2020` to generic `self_insurance_status` or similar
    85	2. Replace hardcoded COVID dates with configurable parameters
    86	3. Abstract event-time construction to accept arbitrary treatment dates
    87	
    88	### Phase 3: Archive COVID-Specific Code
    89	1. Move COVID-era DiD scripts to archive/ directory
    90	2. Document archived scripts for reference
    91	3. Remove COVID-specific interaction analyses
    92	
    93	### Phase 4: Create Clean IV Template
    94	1. Build new general-purpose IV analysis script
    95	2. Document IV identification strategy
    96	3. Create reproducible example with test data
```

</details>

### Shell

```bash
$ nl -ba docs/dependency-graph.md | sed -n '1,220p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Total output lines: 221
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# Script Dependency Graph
     2	
     3	This document maps the end-to-end pipeline showing inputs, outputs, and dependencies between scripts in the repository.
     4	
     5	## Pipeline Overview
     6	
     7	```
     8	Raw Data (../Data/raw_data/)
     9	    │
    10	    ├─► data_prep.R ─────────────────► prepared_data_for_analysis.RData
    11	    │       │
    12	    │       └─► data_prep_ins_level_iv.R ─► prepared_data_for_analysis_ins_level_iv.RData
    13	    │
    14	    └─► data_prep_pre_analysis.R ────► data_balanced_pre_analysis.RData
    15	            │
    16	            ├─► data_exploration.R ──► data_with_centered_iv_var.RData
    17	            │
    18	            ├─► DiDs.R ──────────────► Results/*.txt
    19	            │
    20	            ├─► spec_curve_run_models.R ► spec_curve_results.RData
    21	            │       │
    22	            │       └─► spec_curve_print_curve.R ► figures/spec_curve_*.png
    23	            │
    24	            └─► Event Studies.R ─────► figures/mod_*.png
    25	```
    26	
    27	## Detailed Script Dependencies
    28	
    29	### Data Preparation Scripts
    30	
    31	#### data_prep.R
    32	**Purpose:** Primary data preparation - loads raw data, joins IV data, creates treatment variables
    33	
    34	| Type | Item |
    35	|------|------|
    36	| **Sources** | None (standalone) |
    37	| **Inputs** | `../Data/intermediate_data/archive/step_1_f_sch_a_99_20_all_variables.csv` |
    38	| | `../Data/intermediate_data/step_13_panel_for_ols_iv_reg_new.csv` |
    39	| | `../Data/intermediate_data/healthpremium_iv_at.csv` |
    40	| **Outputs** | `../Data/intermediate_data/prepared_data_for_analysis.RData` |
    41	| **Libraries** | data.table, tidyverse, DescTools, MatchIt, vtable, haven |
    42	| **Key Variables Created** | `linsurer_otstAMLR_LARGEGROUP` (IV), `did_fully_2020`, `post_covid`, `ins_status_2020_jan` |
    43	
    44	#### data_prep_ins_level_iv.R
    45	**Purpose:** Alternative data prep with insurance-level IV construction
    46	
    47	| Type | Item |
    48	|------|------|
    49	| **Sources** | None (standalone) |
    50	| **Inputs** | `../Data/intermediate_data/archive/step_1_f_sch_a_99_20_all_variables.csv` |
    51	| | `../Data/intermediate_data/step_13_panel_for_ols_iv_reg_new.csv` |
    52	| | `../Data/intermediate_data/healthpremium_iv_at.csv` |
    53	| **Outputs** | `../Data/intermediate_data/prepared_data_for_analysis_ins_level_iv.RData` |
    54	| **Libraries** | data.table, tidyverse, DescTools, MatchIt, vtable, haven |
    55	| **Key Variables Created** | `iv_var_1`, `iv_var_2`, leave-out mean IVs |
    56	
    57	#### data_prep_pre_analysis.R
    58	**Purpose:** Creates event-time variables, bins, leave-one-out instruments
    59	
    60	| Type | Item |
    61	|------|------|
    62	| **Sources** | None |
    63	| **Inputs** | `../Data/intermediate_data/prepared_data_for_analysis.RData` |
    64	| **Outputs** | `../Data/intermediate_data/data_balanced_pre_analysis.RData` |
    65	| **Libraries** | data.table, tidyverse, DescTools, MatchIt, vtable, haven, fixest |
    66	| **Key Variables Created** | `e_centered` (leave-one-out instrument), `treat`, winsorized outcomes |
    67	
    68	#### data_exploration.R
    69	**Purpose:** Explores alternative IV constructions, creates centered IV variables
    70	
    71	| Type | Item |
    72	|------|------|
    73	| **Sources** | `Functions_and_Options.R` (implicit, not explicitly sourced) |
    74	| **Inputs** | `../Data/intermediate_data/archive/step_1_f_sch_a_99_20_all_variables.csv` |
    75	| | `../Data/intermediate_data/step_13_panel_for_ols_iv_reg_new.csv` |
    76	| | `../Data/intermediate_data/prepared_data_for_analysis.RData` |
    77	| | `../Data/intermediate_data/step22_insurer_czone_HHI.csv` |
    78	| **Outputs** | `../Data/intermediate_data/data_with_centered_iv_var.RData` |
    79	| **Libraries** | data.table, tidyverse, DescTools, MatchIt, vtable, haven, fixest |
    80	| **Key Variables Created** | `iv_var` (centered), `event_time_fac`, interaction FE variables |
    81	
    82	### Analysis Scripts
    83	
    84	#### DiDs.R
    85	**Purpose:** Main DiD/IV analysis with interactions
    86	
    87	| Type | Item |
    88	|------|------|
    89	| **Sources** | `Functions_and_Options.R` |
    90	| **Inputs** | `../Data/intermediate_data/data_balanced_pre_analysis.RData` |
    91	| **Outputs** | `../Data/intermediate_data/data_balanced_pre_analysis_cleaned.RData` |
    92	| | `../Results/visitors_ols_results.txt` |
    93	| | `../Results/visitors_iv_results.txt` |
    94	| | `../Results/visits_ols_results.txt`, etc. |
    95	| **Libraries** | fixest, tidyverse |
    96	
    97	#### DiDs - interact.R…154 chars truncated…Options.R` |
   103	| **Inputs** | `../Data/intermediate_data/data_with_centered_iv_var.RData` |
   104	| | `../Data/intermediate_data/step18_combined_ita_data_part_vars_with_rate.csv.gz` |
   105	| | `../Data/intermediate_data/step18_bls_soii_data_2016.csv.gz` |
   106	| | `../Data/raw_data/ppp_exposure/ppp_exposure_collapse_county_cleaned_with_state_fips.csv` |
   107	| | `../Data/intermediate_data/industry_remote_work_share_2digit_2019.csv` |
   108	| | `../Data/intermediate_data/county_year_dem_Rep_2000_2020.csv` |
   109	| | `../Data/intermediate_data/step_1_f_5500_99_20_collective_bargain_ind.csv` |
   110	| | `../Data/intermediate_data/step19_ein_deal_date.csv` |
   111	| | `../Data/intermediate_data/county_demographics_2019.csv` |
   112	| **Outputs** | `{table_path}/interaction_table1.tex` |
   113	| | `{table_path}/interaction_table2.tex` |
   114	| **Libraries** | tidyverse, fixest, haven, MatchIt |
   115	
   116	#### Event Studies.R
   117	**Purpose:** Event study visualizations
   118	
   119	| Type | Item |
   120	|------|------|
   121	| **Sources** | `Functions_and_Options.R` |
   122	| **Inputs** | `../Data/intermediate_data/data_with_centered_iv_var.RData` |
   123	| | `../Data/intermediate_data/step21_ein_year_employee.dta` |
   124	| **Outputs** | `{figure_path}/mod_visitor.png` |
   125	| | `{figure_path}/mod_dwell.png` |
   126	| | `{figure_path}/mod_visitor_IV.png` |
   127	| | `{figure_path}/mod_dwell_IV.png` |
   128	| **Libraries** | tidyverse, fixest, haven, MatchIt, ggfixest |
   129	
   130	#### try_ivs.R
   131	**Purpose:** Parallel specification search for IV models
   132	
   133	| Type | Item |
   134	|------|------|
   135	| **Sources** | None |
   136	| **Inputs** | `../Data/intermediate_data/prepared_data_for_analysis_ins_level_iv.RData` |
   137	| **Outputs** | `../Data/intermediate_data/spec_curve_results_iv.RData` |
   138	| **Libraries** | tidyverse, fixest, foreach, doParallel, MatchIt |
   139	
   140	#### spec_curve_run_models.R
   141	**Purpose:** Specification curve analysis - runs all model variants
   142	
   143	| Type | Item |
   144	|------|------|
   145	| **Sources** | None |
   146	| **Inputs** | `../Data/intermediate_data/data_balanced_pre_analysis.RData` |
   147	| **Outputs** | `../Data/intermediate_data/spec_curve_results.RData` |
   148	| **Libraries** | tidyverse, fixest, foreach, doParallel, MatchIt |
   149	
   150	#### spec_curve_print_curve.R
   151	**Purpose:** Visualize specification curve results
   152	
   153	| Type | Item |
   154	|------|------|
   155	| **Sources** | `Functions_and_Options.R` |
   156	| **Inputs** | `../Data/intermediate_data/spec_curve_results.RData` |
   157	| **Outputs** | `{figure_path}/spec_curve_raw_visitor_counts.png` |
   158	| | `../Result/spec_curve_results.tex` |
   159	| **Libraries** | magrittr, tidyverse, cowplot, vtable |
   160	
   161	#### analysis.R
   162	**Purpose:** Ad-hoc analysis with insurance-level IV
   163	
   164	| Type | Item |
   165	|------|------|
   166	| **Sources** | None |
   167	| **Inputs** | `../Data/intermediate_data/prepared_data_for_analysis_ins_level_iv.RData` |
   168	| **Outputs** | None (interactive) |
   169	| **Libraries** | fixest, ggplot2, tidyverse |
   170	
   171	#### Visualization.R
   172	**Purpose:** Propensity score visualizations
   173	
   174	| Type | Item |
   175	|------|------|
   176	| **Sources** | None |
   177	| **Inputs** | `../Data/intermediate_data/propensity_data.RDS` |
   178	| **Outputs** | `../Result/reg results/insured_person_count_histogram.png` |
   179	| **Libraries** | ggplot2, data.table |
   180	
   181	### Utility Scripts
   182	
   183	#### Functions_and_Options.R
   184	**Purpose:** Shared functions and project settings
   185	
   186	| Type | Item |
   187	|------|------|
   188	| **Sources** | None |
   189	| **Inputs** | None |
   190	| **Outputs** | None (sourced by other scripts) |
   191	| **Provides** | `figure_path`, `table_path`, `calculate_F_eff()`, `variable_cap()`, `sumStats()`, `add_stars()` |
   192	
   193	#### load_acs_data.R
   194	**Purpose:** Load ACS demographic data
   195	
   196	| Type | Item |
   197	|------|------|
   198	| **Sources** | `Functions_and_Options.R` |
   199	| **Inputs** | Census API |
   200	| **Outputs** | `../Data/intermediate_data/county_demographics_2019.csv` |
   201	| **Libraries** | tidyverse, tidycensus, haven |
   202	
   203	#### install_packages.R
   204	**Purpose:** Package installation helper
   205	
   206	| Type | Item |
   207	|------|------|
   208	| **Sources** | None |
   209	| **Inputs** | None |
   210	| **Outputs** | None (installs packages) |
   211	
   212	#### Test_Control_Function.r
   213	**Purpose:** Simulation for control function approach
   214	
   215	| Type | Item |
   216	|------|------|
   217	| **Sources** | None |
   218	| **Inputs** | None (generates simulated data) |
   219	| **Outputs** | None (interactive) |
   220	| **Libraries** | fixest, ggplot2, dplyr |
```

</details>

### Shell

```bash
$ nl -ba CLAUDE.md | sed -n '1,200p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	<!-- ORCHESTRATOR-HEADER-START -->
     2	# Project Automation with Orchestrator
     3	
     4	Use `orchestrator` for multi-step tasks. **It may take a while—let it cook!**
     5	
     6	## When to Use
     7	
     8	**USE orchestrator for:** Multi-step features, data workflows, writing documents, refactoring
     9	
    10	**DON'T use for:** Single-file edits, answering questions, running one command
    11	
    12	---
    13	
    14	## Quick Reference
    15	
    16	```bash
    17	# Create & run projects
    18	orchestrator new plan.md                  # Create from markdown
    19	orchestrator run projects/my-project.json # Execute (autonomous)
    20	orchestrator status projects/my-project.json
    21	
    22	# Code quality
    23	orchestrator review project.json          # Find AI slop
    24	orchestrator slop project.json            # Remove AI slop
    25	orchestrator clean project.json           # Remove artifacts
    26	
    27	# Writing
    28	orchestrator write project.json "Write intro"
    29	orchestrator edit project.json            # Editorial review
    30	orchestrator copyedit project.json        # Final polish
    31	
    32	# Skills
    33	orchestrator skills list                  # List all skills
    34	orchestrator skills info <name>           # Show skill details
    35	
    36	# Utilities
    37	orchestrator init                         # Scan project structure
    38	orchestrator audit project.json --fix     # Fix data issues
    39	orchestrator docs                         # Full documentation
    40	```
    41	
    42	---
    43	
    44	## Sprint Statuses
    45	
    46	| Status | Meaning |
    47	|--------|---------|
    48	| `pending` | Not started |
    49	| `in_progress` | Developer working |
    50	| `complete` | Passed QA |
    51	| `blocked` | Needs human help |
    52	
    53	---
    54	
    55	## Troubleshooting
    56	
    57	```bash
    58	# CLI not found? Check installation
    59	claude --version
    60	
    61	# Sprint stuck? Clear and retry
    62	orchestrator update project.json sprint-001 --clear-blocked
    63	
    64	# Data issues? Audit and fix
    65	orchestrator audit project.json --fix
    66	```
    67	
    68	**More info:** `orchestrator docs` or `orchestrator <command> --help`
    69	
    70	<!-- ORCHESTRATOR-HEADER-END -->
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
$ rg -n "TODO|FIXME|placeholder|Your code here|TBD|lorem|XXX" -S .
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
$ rg -n "simulate|simulated|synthetic|dummy|fallback|graceful|default|FileNotFound|tryCatch|except\b|except:|pass\b" -S .
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
./docs/dependency-graph.md:218:| **Inputs** | None (generates simulated data) |
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
$ rg --files -g'*.R' -g'*.r' -g'*.py' -g'*.js' -g'*.ts' -g'*.jsx' -g'*.tsx' -g'*.go' -g'*.rs' -g'*.java' -g'*.rb'
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
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Shell

```bash
$ rg -n "CLAUDE\.md" -S .
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
$ update_plan
```

<details><summary>stdout</summary>

```text
Plan updated
```

</details>

### Shell

```bash
$ sed -n '17,24p' docs/core-pipeline.md
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
### Key Identifiers

- `ein`: Primary unit identifier (firm)
- `year` + `month`: Time dimensions (creates `year_month` factor)
- `naic_code`: Links firms to insurers for IV construction
- `czone`: Commuting zone for geographic fixed effects
- `first_two_digits_business_code`: Industry classification (derived from `business_code`)
```

</details>

### Shell

```bash
$ sed -n '109,128p' docs/core-pipeline.md
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
### Script-by-Script Changes

#### data_prep.R

**Keep:**
- Raw data loading (lines 17-48)
- IV data join (lines 56-73)
- State filtering (lines 77-78)
- `fully_ratio` filter (line 81)
- NAIC code cleaning (lines 117-121)
- Matching for missing IV imputation (lines 123-204)
- Backfill czone logic (lines 153-165)
- Business code extraction (lines 168-173)

**Remove:**
- Lines 83-90: `ins_status_2020_jan`, `ins_status_2018_jan` creation
- Lines 98-100: `post_covid` creation
- Lines 102-107: `did_fully`, `did_fully_2020` creation
- Lines 132-141: `iv_var_2019`, `iv_var_2018`, `iv_var_pre_2020` creation
```

</details>

### Shell

```bash
$ sed -n '1,28p' docs/audit-report.md
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
# Code Audit Report

This document inventories all R and Python scripts in the repository and classifies each file for the refactoring effort to remove COVID-specific code and focus on general IV analysis of self-insurance status.

## File Inventory

| Path | Action | Reason |
|------|--------|--------|
| data_prep.R | **Modify** | Core data preparation script. Contains COVID-specific variables (`post_covid`, `did_fully_2020`, `ins_status_2020_jan`) that need generalization. Preserves primary IV (`linsurer_otstAMLR_LARGEGROUP`). |
| data_prep_ins_level_iv.R | **Modify** | Alternative data prep with insurance-level IV construction. Contains COVID-specific variables (`post_covid`, `did_fully_2020`). Core IV logic should be preserved. |
| data_prep_pre_analysis.R | **Modify** | Pre-analysis data preparation. Contains COVID-specific references (event time relative to March 2020, `did_fully_2020`). Needs generalization of event time variables. |
| Functions_and_Options.R | **Keep** | Shared utility functions and paths. Core infrastructure with no COVID-specific code. Contains `calculate_F_eff`, `variable_cap`, `sumStats`. |
| DiDs.R | **Archive** | COVID-era DiD analysis script. Directly tied to COVID treatment timing (March 2020). Replace with general IV analysis template. |
| DiDs - interact.R | **Archive** | COVID-era DiD with heterogeneous treatment effects. Uses `xvar_2020`, `post_covid` extensively. COVID-specific framing throughout. |
| Event Studies.R | **Archive** | Event study plots centered on COVID treatment date (March 2020). Uses `event_time_fac` tied to COVID timing. |
| try_ivs.R | **Archive** | Specification search script for COVID-era DiD-IV. Uses `did_fully_2020` and COVID-specific sample restrictions. |
| spec_curve_run_models.R | **Archive** | Specification curve analysis for COVID DiD. Treatment variable is `did_fully_2020`. |
| spec_curve_print_curve.R | **Archive** | Visualization of specification curves. Depends on COVID-specific spec_curve_run_models.R output. |
| analysis.R | **Archive** | Ad-hoc analysis script using COVID-era variables (`did_fully_2020`, `post_covid`). Exploratory rather than core pipeline. |
| Visualization.R | **Keep** | Generic visualization utilities. No COVID-specific code. Creates propensity score histograms. |
| data_exploration.R | **Modify** | Creates centered IV variables and event study data. Contains COVID timing references but core IV construction logic is reusable. |
| Test_Control_Function.r | **Keep** | Simulation script for control function approach. Educational/testing only. No COVID-specific code. |
| install_packages.R | **Keep** | Package installation helper. Infrastructure only. |
| load_acs_data.R | **Keep** | ACS demographic data loader. Generic data ingestion. |
| collect_reg_results.py | **Archive** | Collects bootstrap regression results. Tied to deprecated result structure. |
| llm_temp_code/explore_ppp_data.py | **Archive** | PPP exposure data exploration. COVID-specific (PPP was pandemic relief). |
| explore_remote_work.py | **Keep** | Creates remote work shares by industry. Useful covariate not COVID-specific. |
```

</details>

### Shell

```bash
$ sed -n '76,96p' docs/audit-report.md
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
## Recommended Actions by Priority

### Phase 1: Preserve Core Pipeline
1. Document current data flow from raw data to analysis-ready datasets
2. Identify the minimal set of scripts needed for IV analysis
3. Extract reusable IV construction logic from data_prep.R

### Phase 2: Generalize Treatment Variables
1. Rename `did_fully_2020` to generic `self_insurance_status` or similar
2. Replace hardcoded COVID dates with configurable parameters
3. Abstract event-time construction to accept arbitrary treatment dates

### Phase 3: Archive COVID-Specific Code
1. Move COVID-era DiD scripts to archive/ directory
2. Document archived scripts for reference
3. Remove COVID-specific interaction analyses

### Phase 4: Create Clean IV Template
1. Build new general-purpose IV analysis script
2. Document IV identification strategy
3. Create reproducible example with test data
```

</details>

### Shell

```bash
$ sed -n '1,25p' docs/dependency-graph.md
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
# Script Dependency Graph

This document maps the end-to-end pipeline showing inputs, outputs, and dependencies between scripts in the repository.

## Pipeline Overview

```
Raw Data (../Data/raw_data/)
    │
    ├─► data_prep.R ─────────────────► prepared_data_for_analysis.RData
    │       │
    │       └─► data_prep_ins_level_iv.R ─► prepared_data_for_analysis_ins_level_iv.RData
    │
    └─► data_prep_pre_analysis.R ────► data_balanced_pre_analysis.RData
            │
            ├─► data_exploration.R ──► data_with_centered_iv_var.RData
            │
            ├─► DiDs.R ──────────────► Results/*.txt
            │
            ├─► spec_curve_run_models.R ► spec_curve_results.RData
            │       │
            │       └─► spec_curve_print_curve.R ► figures/spec_curve_*.png
            │
            └─► Event Studies.R ─────► figures/mod_*.png
```
```

</details>

### Shell

```bash
$ sed -n '3,28p' docs/audit-report.md
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
This document inventories all R and Python scripts in the repository and classifies each file for the refactoring effort to remove COVID-specific code and focus on general IV analysis of self-insurance status.

## File Inventory

| Path | Action | Reason |
|------|--------|--------|
| data_prep.R | **Modify** | Core data preparation script. Contains COVID-specific variables (`post_covid`, `did_fully_2020`, `ins_status_2020_jan`) that need generalization. Preserves primary IV (`linsurer_otstAMLR_LARGEGROUP`). |
| data_prep_ins_level_iv.R | **Modify** | Alternative data prep with insurance-level IV construction. Contains COVID-specific variables (`post_covid`, `did_fully_2020`). Core IV logic should be preserved. |
| data_prep_pre_analysis.R | **Modify** | Pre-analysis data preparation. Contains COVID-specific references (event time relative to March 2020, `did_fully_2020`). Needs generalization of event time variables. |
| Functions_and_Options.R | **Keep** | Shared utility functions and paths. Core infrastructure with no COVID-specific code. Contains `calculate_F_eff`, `variable_cap`, `sumStats`. |
| DiDs.R | **Archive** | COVID-era DiD analysis script. Directly tied to COVID treatment timing (March 2020). Replace with general IV analysis template. |
| DiDs - interact.R | **Archive** | COVID-era DiD with heterogeneous treatment effects. Uses `xvar_2020`, `post_covid` extensively. COVID-specific framing throughout. |
| Event Studies.R | **Archive** | Event study plots centered on COVID treatment date (March 2020). Uses `event_time_fac` tied to COVID timing. |
| try_ivs.R | **Archive** | Specification search script for COVID-era DiD-IV. Uses `did_fully_2020` and COVID-specific sample restrictions. |
| spec_curve_run_models.R | **Archive** | Specification curve analysis for COVID DiD. Treatment variable is `did_fully_2020`. |
| spec_curve_print_curve.R | **Archive** | Visualization of specification curves. Depends on COVID-specific spec_curve_run_models.R output. |
| analysis.R | **Archive** | Ad-hoc analysis script using COVID-era variables (`did_fully_2020`, `post_covid`). Exploratory rather than core pipeline. |
| Visualization.R | **Keep** | Generic visualization utilities. No COVID-specific code. Creates propensity score histograms. |
| data_exploration.R | **Modify** | Creates centered IV variables and event study data. Contains COVID timing references but core IV construction logic is reusable. |
| Test_Control_Function.r | **Keep** | Simulation script for control function approach. Educational/testing only. No COVID-specific code. |
| install_packages.R | **Keep** | Package installation helper. Infrastructure only. |
| load_acs_data.R | **Keep** | ACS demographic data loader. Generic data ingestion. |
| collect_reg_results.py | **Archive** | Collects bootstrap regression results. Tied to deprecated result structure. |
| llm_temp_code/explore_ppp_data.py | **Archive** | PPP exposure data exploration. COVID-specific (PPP was pandemic relief). |
| explore_remote_work.py | **Keep** | Creates remote work shares by industry. Useful covariate not COVID-specific. |
```

</details>

### Shell

```bash
$ sed -n '3,25p' docs/dependency-graph.md
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
This document maps the end-to-end pipeline showing inputs, outputs, and dependencies between scripts in the repository.

## Pipeline Overview

```
Raw Data (../Data/raw_data/)
    │
    ├─► data_prep.R ─────────────────► prepared_data_for_analysis.RData
    │       │
    │       └─► data_prep_ins_level_iv.R ─► prepared_data_for_analysis_ins_level_iv.RData
    │
    └─► data_prep_pre_analysis.R ────► data_balanced_pre_analysis.RData
            │
            ├─► data_exploration.R ──► data_with_centered_iv_var.RData
            │
            ├─► DiDs.R ──────────────► Results/*.txt
            │
            ├─► spec_curve_run_models.R ► spec_curve_results.RData
            │       │
            │       └─► spec_curve_print_curve.R ► figures/spec_curve_*.png
            │
            └─► Event Studies.R ─────► figures/mod_*.png
```
```

</details>

### Shell

```bash
$ nl -ba docs/audit-report.md | sed -n '68,100p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
    68	- COVID-specific try_ivs.R
    69	- PPP-related Python scripts
    70	
    71	**Hardcoded Dates:**
    72	- `year == 2020 & month >= 3` - COVID treatment start
    73	- `treatment_date = as.Date("2020-03-01")` - Event study reference
    74	- `year < 2020` - Pre-period definitions
    75	
    76	## Recommended Actions by Priority
    77	
    78	### Phase 1: Preserve Core Pipeline
    79	1. Document current data flow from raw data to analysis-ready datasets
    80	2. Identify the minimal set of scripts needed for IV analysis
    81	3. Extract reusable IV construction logic from data_prep.R
    82	
    83	### Phase 2: Generalize Treatment Variables
    84	1. Rename `did_fully_2020` to generic `self_insurance_status` or similar
    85	2. Replace hardcoded COVID dates with configurable parameters
    86	3. Abstract event-time construction to accept arbitrary treatment dates
    87	
    88	### Phase 3: Archive COVID-Specific Code
    89	1. Move COVID-era DiD scripts to archive/ directory
    90	2. Document archived scripts for reference
    91	3. Remove COVID-specific interaction analyses
    92	
    93	### Phase 4: Create Clean IV Template
    94	1. Build new general-purpose IV analysis script
    95	2. Document IV identification strategy
    96	3. Create reproducible example with test data
```

</details>

### Shell

```bash
$ nl -ba docs/core-pipeline.md | sed -n '13,30p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
    13	| Insurer | `naic_code` | NAIC insurer code |
    14	| Industry | `business_code` | Industry classification |
    15	| Firm Size | `ins_prsn_covered_eoy_cnt` | Persons covered at end of year |
    16	
    17	### Key Identifiers
    18	
    19	- `ein`: Primary unit identifier (firm)
    20	- `year` + `month`: Time dimensions (creates `year_month` factor)
    21	- `naic_code`: Links firms to insurers for IV construction
    22	- `czone`: Commuting zone for geographic fixed effects
    23	- `first_two_digits_business_code`: Industry classification (derived from `business_code`)
    24	
    25	## Instruments
    26	
    27	### Primary Instrument
    28	
    29	**`linsurer_otstAMLR_LARGEGROUP`** - Insurer loss ratio for large group market
    30
```

</details>

### Shell

```bash
$ nl -ba docs/core-pipeline.md | sed -n '103,135p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
   103	| `year > 2020` | data_prep.R:100 | Configurable post-period |
   104	| `year == 2020 & month == 1` | data_prep.R:87-88 | Configurable base period |
   105	| `year == 2018 & month == 1` | data_prep.R:88 | Remove entirely |
   106	| `year < 2020` | data_prep.R:139 | Configurable pre-period |
   107	| `year == 2020 & month < 3` | data_prep_pre_analysis.R:90 | Remove event-time logic |
   108	
   109	### Script-by-Script Changes
   110	
   111	#### data_prep.R
   112	
   113	**Keep:**
   114	- Raw data loading (lines 17-48)
   115	- IV data join (lines 56-73)
   116	- State filtering (lines 77-78)
   117	- `fully_ratio` filter (line 81)
   118	- NAIC code cleaning (lines 117-121)
   119	- Matching for missing IV imputation (lines 123-204)
   120	- Backfill czone logic (lines 153-165)
   121	- Business code extraction (lines 168-173)
   122	
   123	**Remove:**
   124	- Lines 83-90: `ins_status_2020_jan`, `ins_status_2018_jan` creation
   125	- Lines 98-100: `post_covid` creation
   126	- Lines 102-107: `did_fully`, `did_fully_2020` creation
   127	- Lines 132-141: `iv_var_2019`, `iv_var_2018`, `iv_var_pre_2020` creation
   128	
   129	#### data_prep_ins_level_iv.R
   130	
   131	**Keep:**
   132	- Raw data loading (lines 17-45)
   133	- IV data join (lines 54-70)
   134	- State/insurance filtering (lines 73-76)
   135	- NAIC matching (lines 78-112)
```

</details>

### Shell

```bash
$ nl -ba docs/dependency-graph.md | sed -n '1,40p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
     1	# Script Dependency Graph
     2	
     3	This document maps the end-to-end pipeline showing inputs, outputs, and dependencies between scripts in the repository.
     4	
     5	## Pipeline Overview
     6	
     7	```
     8	Raw Data (../Data/raw_data/)
     9	    │
    10	    ├─► data_prep.R ─────────────────► prepared_data_for_analysis.RData
    11	    │       │
    12	    │       └─► data_prep_ins_level_iv.R ─► prepared_data_for_analysis_ins_level_iv.RData
    13	    │
    14	    └─► data_prep_pre_analysis.R ────► data_balanced_pre_analysis.RData
    15	            │
    16	            ├─► data_exploration.R ──► data_with_centered_iv_var.RData
    17	            │
    18	            ├─► DiDs.R ──────────────► Results/*.txt
    19	            │
    20	            ├─► spec_curve_run_models.R ► spec_curve_results.RData
    21	            │       │
    22	            │       └─► spec_curve_print_curve.R ► figures/spec_curve_*.png
    23	            │
    24	            └─► Event Studies.R ─────► figures/mod_*.png
    25	```
    26	
    27	## Detailed Script Dependencies
    28	
    29	### Data Preparation Scripts
    30	
    31	#### data_prep.R
    32	**Purpose:** Primary data preparation - loads raw data, joins IV data, creates treatment variables
    33	
    34	| Type | Item |
    35	|------|------|
    36	| **Sources** | None (standalone) |
    37	| **Inputs** | `../Data/intermediate_data/archive/step_1_f_sch_a_99_20_all_variables.csv` |
    38	| | `../Data/intermediate_data/step_13_panel_for_ols_iv_reg_new.csv` |
    39	| | `../Data/intermediate_data/healthpremium_iv_at.csv` |
    40	| **Outputs** | `../Data/intermediate_data/prepared_data_for_analysis.RData` |
```

</details>

### Shell

```bash
$ nl -ba docs/core-pipeline.md | sed -n '27,40p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
    27	### Primary Instrument
    28	
    29	**`linsurer_otstAMLR_LARGEGROUP`** - Insurer loss ratio for large group market
    30	
    31	- Source: `healthpremium_iv_at.csv`
    32	- Constructed at insurer-year level
    33	- Joined to firm data via `ein` and `year`
    34	- Missing values imputed via matching on `ins_prsn_covered_eoy_cnt` within `year + month + industry + czone` cells
    35	
    36	This instrument exploits variation in insurer financial health (loss ratios) that affects employer insurance costs but is plausibly exogenous to individual firm health outcomes.
    37	
    38	### Alternative Instruments
    39	
    40	| Variable | Script | Description |
```

</details>

### Shell

```bash
$ nl -ba docs/core-pipeline.md | sed -n '47,70p'
```

<details><summary>stdout</summary>

```text
Exit code: 0
Wall time: 0.1 seconds
Output:
/opt/homebrew/Library/Homebrew/cmd/shellenv.sh: line 18: /bin/ps: Operation not permitted
    47	### Generalized Treatment Variable
    48	
    49	**Rename:** `did_fully_2020` → `self_insurance_status`
    50	
    51	The current `did_fully_2020` is defined as:
    52	```r
    53	did_fully_2020 = ins_status_2020_jan * post_covid
    54	```
    55	
    56	This is COVID-specific (freezes insurance status at January 2020 and interacts with post-COVID indicator). The generalized treatment should be:
    57	
    58	**`self_insurance_status`** = `fully_ratio` (continuous) or a binary/categorical measure of self-insurance
    59	
    60	For IV analysis without event-study structure:
    61	- Use `fully_ratio` directly as the endogenous regressor
    62	- Instrument with `linsurer_otstAMLR_LARGEGROUP`
    63	
    64	For event-study or DiD structure with arbitrary treatment timing:
    65	- Define treatment status at a configurable base period
    66	- Create post-treatment indicator relative to arbitrary date (not hardcoded March 2020)
    67	
    68	### Core Insurance Variables (Keep)
    69	
    70	| Variable | Description |
```

</details>

### Codex

FINDINGS:
- file: docs/core-pipeline.md
  lines: 17-24
  pattern: excessive_comments
  code: |
    ### Key Identifiers

    - `ein`: Primary unit identifier (firm)
    - `year` + `month`: Time dimensions (creates `year_month` factor)
    - `naic_code`: Links firms to insurers for IV construction
    - `czone`: Commuting zone for geographic fixed effects
    - `first_two_digits_business_code`: Industry classification (derived from `business_code`)
  recommendation: Remove this section (or merge into the “Panel Structure” table) since it restates the same identifiers without adding non-obvious context.

- file: docs/core-pipeline.md
  lines: 109-128
  pattern: dead_code
  code: |
    ### Script-by-Script Changes

    #### data_prep.R

    **Keep:**
    - Raw data loading (lines 17-48)
    - IV data join (lines 56-73)
    - State filtering (lines 77-78)
    - `fully_ratio` filter (line 81)
    - NAIC code cleaning (lines 117-121)
    - Matching for missing IV imputation (lines 123-204)
    - Backfill czone logic (lines 153-165)
    - Business code extraction (lines 168-173)

    **Remove:**
    - Lines 83-90: `ins_status_2020_jan`, `ins_status_2018_jan` creation
    - Lines 98-100: `post_covid` creation
    - Lines 102-107: `did_fully`, `did_fully_2020` creation
    - Lines 132-141: `iv_var_2019`, `iv_var_2018`, `iv_var_pre_2020` creation
  recommendation: Remove this line-number-specific “Keep/Remove” checklist until the referenced scripts exist in-repo and line numbers are verifiable; it’s brittle and currently non-auditable.

- file: docs/audit-report.md
  lines: 3-28
  pattern: dead_code
  code: |
    This document inventories all R and Python scripts in the repository and classifies each file for the refactoring effort to remove COVID-specific code and focus on general IV analysis of self-insurance status.

    ## File Inventory

    | Path | Action | Reason |
    |------|--------|--------|
    | data_prep.R | **Modify** | Core data preparation script. Contains COVID-specific variables (`post_covid`, `did_fully_2020`, `ins_status_2020_jan`) that need generalization. Preserves primary IV (`linsurer_otstAMLR_LARGEGROUP`). |
    | data_prep_ins_level_iv.R | **Modify** | Alternative data prep with insurance-level IV construction. Contains COVID-specific variables (`post_covid`, `did_fully_2020`). Core IV logic should be preserved. |
    | data_prep_pre_analysis.R | **Modify** | Pre-analysis data preparation. Contains COVID-specific references (event time relative to March 2020, `did_fully_2020`). Needs generalization of event time variables. |
    | Functions_and_Options.R | **Keep** | Shared utility functions and paths. Core infrastructure with no COVID-specific code. Contains `calculate_F_eff`, `variable_cap`, `sumStats`. |
    | DiDs.R | **Archive** | COVID-era DiD analysis script. Directly tied to COVID treatment timing (March 2020). Replace with general IV analysis template. |
    | DiDs - interact.R | **Archive** | COVID-era DiD with heterogeneous treatment effects. Uses `xvar_2020`, `post_covid` extensively. COVID-specific framing throughout. |
    | Event Studies.R | **Archive** | Event study plots centered on COVID treatment date (March 2020). Uses `event_time_fac` tied to COVID timing. |
    | try_ivs.R | **Archive** | Specification search script for COVID-era DiD-IV. Uses `did_fully_2020` and COVID-specific sample restrictions. |
    | spec_curve_run_models.R | **Archive** | Specification curve analysis for COVID DiD. Treatment variable is `did_fully_2020`. |
    | spec_curve_print_curve.R | **Archive** | Visualization of specification curves. Depends on COVID-specific spec_curve_run_models.R output. |
    | analysis.R | **Archive** | Ad-hoc analysis script using COVID-era variables (`did_fully_2020`, `post_covid`). Exploratory rather than core pipeline. |
    | Visualization.R | **Keep** | Generic visualization utilities. No COVID-specific code. Creates propensity score histograms. |
    | data_exploration.R | **Modify** | Creates centered IV variables and event study data. Contains COVID timing references but core IV construction logic is reusable. |
    | Test_Control_Function.r | **Keep** | Simulation script for control function approach. Educational/testing only. No COVID-specific code. |
    | install_packages.R | **Keep** | Package installation helper. Infrastructure only. |
    | load_acs_data.R | **Keep** | ACS demographic data loader. Generic data ingestion. |
    | collect_reg_results.py | **Archive** | Collects bootstrap regression results. Tied to deprecated result structure. |
    | llm_temp_code/explore_ppp_data.py | **Archive** | PPP exposure data exploration. COVID-specific (PPP was pandemic relief). |
    | explore_remote_work.py | **Keep** | Creates remote work shares by industry. Useful covariate not COVID-specific. |
  recommendation: Remove the “inventories all scripts” claim and the table as-written; regenerate from actual repo contents so it’s not a hallucinated/stale inventory.

- file: docs/audit-report.md
  lines: 76-96
  pattern: ai_placeholder_comments
  code: |
    ## Recommended Actions by Priority

    ### Phase 1: Preserve Core Pipeline
    1. Document current data flow from raw data to analysis-ready datasets
    2. Identify the minimal set of scripts needed for IV analysis
    3. Extract reusable IV construction logic from data_prep.R

    ### Phase 2: Generalize Treatment Variables
    1. Rename `did_fully_2020` to generic `self_insurance_status` or similar
    2. Replace hardcoded COVID dates with configurable parameters
    3. Abstract event-time construction to accept arbitrary treatment dates

    ### Phase 3: Archive COVID-Specific Code
    1. Move COVID-era DiD scripts to archive/ directory
    2. Document archived scripts for reference
    3. Remove COVID-specific interaction analyses

    ### Phase 4: Create Clean IV Template
    1. Build new general-purpose IV analysis script
    2. Document IV identification strategy
    3. Create reproducible example with test data
  recommendation: Remove this generic phased to-do list unless it’s tied to concrete, in-repo artifacts (specific scripts/PRs/issues); otherwise it reads like planning filler.

- file: docs/dependency-graph.md
  lines: 3-25
  pattern: dead_code
  code: |
    This document maps the end-to-end pipeline showing inputs, outputs, and dependencies between scripts in the repository.

    ## Pipeline Overview

    ```
    Raw Data (../Data/raw_data/)
        │
        ├─► data_prep.R ─────────────────► prepared_data_for_analysis.RData
        │       │
        │       └─► data_prep_ins_level_iv.R ─► prepared_data_for_analysis_ins_level_iv.RData
        │
        └─► data_prep_pre_analysis.R ────► data_balanced_pre_analysis.RData
                │
                ├─► data_exploration.R ──► data_with_centered_iv_var.RData
                │
                ├─► DiDs.R ──────────────► Results/*.txt
                │
                ├─► spec_curve_run_models.R ► spec_curve_results.RData
                │       │
                │       └─► spec_curve_print_curve.R ► figures/spec_curve_*.png
                │
                └─► Event Studies.R ─────► figures/mod_*.png
    ```
  recommendation: Remove this overview until it can be generated from real scripts in this repo; as-is it documents dependencies that don’t exist in the workspace.

SUMMARY:
- Files reviewed: 4
- Total findings: 5
- By pattern:
  - excessive_comments: 1
  - dead_code: 3
  - ai_placeholder_comments: 1

ISSUES_FOUND:
- The workspace contains no files matching the review patterns (`*.R`, `*.py`, etc.); the sprint-priority files (`data_prep.R`, `data_prep_ins_level_iv.R`, `data_prep_pre_analysis.R`) are not present, so code-level slop/hidden-fallback review wasn’t possible.
- docs/core-pipeline.md:33 says the insurer-year IV is “Joined to firm data via `ein` and `year`”, which conflicts with the insurer linkage described elsewhere (`naic_code`); this needs correction/confirmation.
- docs/core-pipeline.md:58-62 defines `self_insurance_status` as `fully_ratio` (share fully insured); confirm intended direction/naming to avoid inverted interpretation.
- NEEDS_HUMAN_REVIEW: Decide whether the missing scripts should be added to this repo (docs are forward-looking) or whether the docs should be rewritten to match the current repo snapshot (docs are hallucinated/stale).

---

**Models seen:** gpt-5.2

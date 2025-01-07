# README for LLM

This README is **not** for other human collaborators. It is for you, the Large Language Model (LLM), to understand how this project is structured and how you should approach writing or modifying any code here.

---

## 1. Purpose of This Repository
This repository focuses on econometric analysis of health insurance and worker health outcomes using R (and occasionally Python). All data-related scripts, analysis scripts, and utility functions reside here.

---

## 2. Data Location
- **Data Are Outside the Main Workspace Folder**  
  All raw and intermediate data live in a folder **outside** this repository, typically accessible via `../Data` (e.g., `../Data/raw_data/` or `../Data/intermediate_data/`).  
- **Why We Keep It Out**  
  We do not store large or sensitive data in the repository itself to avoid accidental commits and to keep the repo light.

---
  
## 3. How the LLM Should Handle Data
1. **Do Not Attempt to Pull or Fetch** the actual data from any external source.  
2. **Respect the Relative Paths** like `../Data/...`, which appear in the code.  
3. **Do Not Rename** any existing file paths or variables associated with data loading.  

---

## 4. Key R Scripts and Their Purpose
- **`data_prep.R`**  
  Prepares raw data, cleans it, and saves processed data as `.RData` files in `../Data/intermediate_data/`.
- **Main Analysis Scripts** (e.g., `DiDs.R`, `Main IV.R`, `analysis.R`)  
  Perform difference-in-differences, IV estimations, and other econometric analyses using `fixest` and `tidyverse`.
- **Utility Files** (e.g., `Functions_and_Options.R`)  
  Contain custom functions, project paths, and general options.  

---

## 5. Project Conventions for the LLM
- **.cursorrules**  
  This file (in the root directory) sets the AI usage guidelines:
  - **No changing existing variable names**.
  - **Load libraries at the top**, using `library(tidyverse)` for data manipulation.
  - **Use `fixest`** for regressions (including OLS and 2SLS).
  - **Store** intermediate objects as `.RData`.
  - **Clear the workspace** at the top of new R scripts unless they’re only short helper scripts.
  - **Comment** code with self-contained explanations (no “change logs” or references to previous modifications).
- **Avoid Hard-coded Changes**  
  When you (the LLM) make suggestions, do not disrupt the project’s directory structure or naming conventions.
- **Limit Dependencies**  
  Do not install or require additional R/Python packages unless strictly needed.

---

## 6. Useful References
- **`.cursorrules`**: Thorough explanation of coding and documentation style expected from you.  
- **Project Scripts**: For a consistent style, follow the patterns already established in `data_prep.R`, `DiDs.R`, `analysis.R`, etc.

---

## 7. Summary
This README ensures that you, the Large Language Model, handle data and code modifications correctly within this project. Remember:
1. **Data** stays in `../Data/`, not inside this folder.
2. **Respect** existing code, variable names, and structure.
3. **Follow** `.cursorrules` for best practices (e.g., no partial logs, clear but minimal comments, consistent style).

If you have any questions or need clarifications, refer to `.cursorrules` in the project root.

---

## 8. File Overviews

Below is a brief description of the main files in this repository and what each of them does:

- data_prep.R  
  Prepares and cleans raw data, then saves processed data in the intermediate data folder.  

- data_prep_ins_level_iv.R  
  Similar to data_prep.R but focuses on insurance-level data and sets up instrumental variables for further analysis.  

- data_prep_pre_analysis.R  
  Performs additional pre-analysis data cleaning steps, such as creating event-time variables and binning.  

- analysis.R  
  Runs regression analyses (e.g., using fixest) and other exploratory models on the processed data.

- Functions_and_Options.R  
  Stores custom functions, project options, and file paths. Often sourced by other scripts to maintain a consistent style and shared utilities.

- DiDs.R  
  A script for difference-in-differences analyses, loading intermediate data and specifying fixest models.  

- DiDs - interact.R  
  Another difference-in-differences script that includes interaction terms.  

- Main DiD.R  
  A primary difference-in-differences script that sets up the data, defines variables of interest, and runs core DiD models.  

- Main IV.R  
  Runs key instrumental variables analyses. This script defines the preferred IVs, performs logging/winsorizing, and stores regression results and event-study plots.

- Main IV - Tables.R  
  Focuses on building LaTeX tables or other outputs from the IV results to ensure consistent reporting of estimates, standard errors, and significance stars.  

- Visualization.R  
  Creates plots to visualize distributions, histograms, or other descriptive statistics of the data.  

- spec_curve_run_models.R  
  Generates a “specification curve” by running multiple combinations of model specifications in parallel, allowing you to see how estimates vary with different choices.  

- spec_curve_print_curve.R  
  Takes the outputs from spec_curve_run_models.R and produces informative summary plots or LaTeX tables describing the range of estimates.

- try_ivs.R  
  Tests additional or alternative instrumental variable approaches. Often used to experiment with new loading, logging, or matching settings.

- collect_reg_results.py  
  A Python script that merges or consolidates regression results from multiple outputs into a single Excel workbook or table for easier review.  

- .gitignore  
  Lists files and directories that should be ignored by version control (e.g., large data files or environment files).

This supplementary section gives a quick overview of each file’s purpose and how it fits into the broader project workflow.

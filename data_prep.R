# nolint start: line_length_linter, trailing_whitespace_linter.

# Clear workspace
rm(list = ls())
options(width = 200)

# Load required libraries
library(data.table)
library(tidyverse)
library(DescTools)
library(MatchIt)
library(vtable)
library(haven)

# Define file paths for project directories
project_dir <- "../Data"
data_dir <- file.path(project_dir, "raw_data/5500/Form_5500")
interm_dir <- file.path(project_dir, "intermediate_data")
output_dir <- "../Result/reg results"

# File with all costs
data_all <- fread(file.path(interm_dir, "./archive/step_1_f_sch_a_99_20_all_variables.csv"))

# Filter to only health plans and add up tax and retention costs
data_all_sum <- data_all %>%
  filter(health_d == 1) %>%
  group_by(sch_a_ein, year) %>%
  summarise(
    sum_admin = sum(wlfr_ret_admin_amt, na.rm = TRUE),
    sum_tax = sum(wlfr_ret_taxes_amt, na.rm = TRUE),
    sum_total = sum(wlfr_ret_tot_amt, na.rm = TRUE),
    naic_code = ins_carrier_naic_code[which.max(ins_prsn_covered_eoy_cnt)]
  )

# Use haven to read the main dta file
data <- fread(file.path(interm_dir, "step_13_panel_for_ols_iv_reg_new.csv"))

# Join in the sum of tax and admin (ein = sch_a_ein)
data <- data %>%
  left_join(data_all_sum, by = c("ein" = "sch_a_ein", "year" = "year"), suffix = c("", ".sum"), relationship = "many-to-many")


names(data)
# Load the new CSV file with instruments
ivdata <- fread(file.path(interm_dir, "healthpremium_iv_at.csv")) %>% as_tibble()

# vtable(data,
#   out = "browser",
#   values = TRUE,
#   summ = c("mean(x)", "median(x)", "min(x)", "max(x)", "propNA(x)")
# )

# Prepare ivdata for joining
ivdata <- ivdata %>%
  mutate(
    year = as.integer(ins_begin_yyyy),
    ein = as.character(SCH_A_EIN) # Convert ein to character
  ) %>%
  select(-ins_begin_yyyy, -SCH_A_EIN)

# Convert ein in data to character as well
data <- data %>%
  mutate(ein = as.character(ein))

# Join data and ivdata
data <- data %>%
  left_join(ivdata, by = c("ein", "year"), suffix = c("", ".iv"), relationship = "many-to-many")

# Remove duplicates
data <- unique(data, by = c("ein", "year", "month"))
data_raw <- data


# Drop missing insurance status and weird states
data <- data %>%
  filter(!(state_abbr %in% c("San German", "", "Guaynabo", "Dorado", "San Juan", "Toa Baja", "Ponce")))

data <- data %>%
  filter(!is.na(fully_ratio))

# Create 2020 jan insurance status variable and apply to all obs from same firm
data <- data %>%
  group_by(ein) %>%
  mutate(
    ins_status_2020_jan = max(ifelse(year == 2020 & month == 1, fully_ratio, 0), na.rm = TRUE),
    ins_status_2018_jan = max(ifelse(year == 2018 & month == 1, fully_ratio, 0), na.rm = TRUE)
  ) %>%
  ungroup()

# Create IV variables
data <- data %>%
  mutate(
    iv_var = linsurer_otstAMLR_LARGEGROUP
  )

# Create post covid variable (starting from month 3 of 2020)
data <- data %>%
  mutate(post_covid = ifelse(year > 2020 | (year == 2020 & month >= 3), 1, 0))

# Create DID variables
data <- data %>%
  mutate(
    did_fully = fully_ratio * post_covid,
    did_fully_2020 = ins_status_2020_jan * post_covid
  )

# Create year-month factor variable
data <- data %>%
  mutate(year_month = as.factor(paste(year, month, sep = "-")))

# Create equal size bins for ins_prsn_covered_eoy_cnt in 2019 and convert to a labeled factor
# First, calculate the bins based on January 2019 data
bins_data <- data %>%
  filter(year == 2019 & month == 1) %>%
  mutate(ins_prsn_covered_eoy_cnt_bins = {
    n_bins <- 10
    bins <- ntile(ins_prsn_covered_eoy_cnt, n_bins)
    bin_labels <- sapply(1:n_bins, function(i) {
      bin_range <- range(ins_prsn_covered_eoy_cnt[bins == i], na.rm = TRUE)
      paste0("[", bin_range[1], ", ", bin_range[2], "]")
    })
    factor(bins, levels = 1:n_bins, labels = bin_labels)
  }) %>%
  mutate(ins_prsn_2019 = ins_prsn_covered_eoy_cnt) %>%  
  select(ein, ins_prsn_covered_eoy_cnt_bins, ins_prsn_2019)

# Then, join the bins back to the original data
data <- data %>%
  left_join(bins_data, by = "ein", relationship = "many-to-many")

# Save the prepared data
save(data, file = file.path(interm_dir, "prepared_data_for_analysis.RData"))

# nolint end

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



# Load the new CSV file with instruments
ivdata <- fread(file.path(interm_dir, "healthpremium_iv_at.csv")) %>% as_tibble()


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

# Drop missing insurance status and weird states
data <- data %>%
  filter(!is.na(fully_ratio)) %>%
  filter(!(state_abbr %in% c("San German", "", "Guaynabo", "Dorado", "San Juan", "Toa Baja", "Ponce")))


# Create a binary treatment variable for matching
data <- data %>%
  mutate(missing = case_when(
    is.na(naic_code) ~ 1,
    naic_code == "" ~ 1,
    TRUE ~ 0
  ))

# # Filter to complete cases for the covariates used in matchit
data <- data %>% filter(complete.cases(fips, state_abbr, manufacturing_dummy, ins_prsn_covered_eoy_cnt, year))

# Apply matchit to get predicted insurer for self insured
match_data <- matchit(
  formula = missing ~ fips + ins_prsn_covered_eoy_cnt + manufacturing_dummy,
  exact = ~state_abbr + year,
  data = data,
  method = "nearest",
  distance = "mahalanobis",
  replace = TRUE,
  verbose = TRUE,
  discard = "none"
)

# Get indices of matched pairs
i <- match_data$match.matrix %>%
  row.names() %>%
  as.character() %>%
  as.numeric()

k <- match_data$match.matrix %>%
  as.character() %>%
  as.numeric()


data[["naic_code"]][i] <- ifelse(is.na(data[["naic_code"]][i]), data[["naic_code"]][k], data[["naic_code"]][i])



# Define the IV variable
data$iv_var_raw <- (data$sum_total) / data$ins_prsn_covered_eoy_cnt

# Create leave-out version of the IV variable by insurer and year
data <- data %>%
  mutate(iv_nonzero = as.numeric(iv_var_raw > 0)) %>%
  mutate(iv_nonzero = ifelse(is.na(iv_nonzero), 0, iv_nonzero)) %>%
  mutate(iv_var_raw_na_0 = ifelse(is.na(iv_var_raw), 0, iv_var_raw)) %>%
  mutate(
    fully_ratio_na_0 = ifelse(is.na(fully_ratio), 0, fully_ratio),
    self_ratio_na_0 = ifelse(is.na(self_ratio), 0, self_ratio)
  )

data <- data %>%
  group_by(naic_code, year, month) %>%
  mutate(
    iv_var_tot_fully = sum(iv_var_raw_na_0 * fully_ratio_na_0 * iv_nonzero, na.rm = TRUE),
    num_obs_fully = sum(fully_ratio_na_0 * iv_nonzero, na.rm = TRUE),
    iv_var_tot_self = sum(iv_var_raw_na_0 * self_ratio_na_0 * iv_nonzero, na.rm = TRUE),
    num_obs_self = sum(self_ratio_na_0 * iv_nonzero, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    iv_var_1 = (iv_var_tot_fully - iv_var_raw_na_0 * fully_ratio_na_0 * iv_nonzero) / (num_obs_fully - fully_ratio_na_0 * iv_nonzero),
    iv_var_2 = (iv_var_tot_self - iv_var_raw_na_0 * self_ratio_na_0 * iv_nonzero) / (num_obs_self - self_ratio_na_0 * iv_nonzero)
  ) %>%
  filter(num_obs_fully > 5, num_obs_self > 5)

# Try leave-out at the ins level
data$iv_var <- data$iv_var_1 - data$iv_var_2

# Self-insurance status is captured by fully_ratio (continuous)

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

table(data$ins_prsn_covered_eoy_cnt_bins)


# Save the prepared data
save(data, file = file.path(interm_dir, "prepared_data_for_analysis_ins_level_iv.RData"))

# nolint end

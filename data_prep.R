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
interm_dir <- file.path(project_dir, "intermediate_data")

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
data_raw <- data


# Drop missing insurance status and weird states
data <- data %>%
  filter(!(state_abbr %in% c("San German", "", "Guaynabo", "Dorado", "San Juan", "Toa Baja", "Ponce")))

data <- data %>%
  filter(!is.na(fully_ratio)) 

# Create IV variables - primary instrument is insurer loss ratio
data <- data %>%
  mutate(
    iv_var = linsurer_otstAMLR_LARGEGROUP
  )

# Self-insurance status is captured by fully_ratio (continuous)

# Create year-month factor variable
data <- data %>%
  mutate(year_month = as.factor(paste(year, month, sep = "-")))



# Remove _0 from naic_code
data <- data %>%
  mutate(
    naic_code = gsub(".0", "", as.character(naic_code))
  )

# Matching to impute missing IV values ----------------------------------------


# Create IV variable for matching
data <- data %>%
  group_by(ein) %>%
  mutate(
    iv_var_dm = linsurer_otstAMLR_LARGEGROUP
  ) %>%
  ungroup() 



# Create an indicator for missing IV values
data <- data %>%
  mutate(
    missing_iv_var = if_else(
      (self_d == 1 | is.na(iv_var_dm)), 1, 0
    )
  )

# Backfill czone data - create a mapping of EIN to their most common czone
ein_czone_mapping <- data %>%
  filter(!is.na(czone)) %>%
  group_by(ein) %>%
  summarise(
    backfill_czone = as.numeric(names(which.max(table(czone))))
  )

# Apply the backfill to rows with missing czone values
data <- data %>%
  left_join(ein_czone_mapping, by = "ein") %>%
  mutate(czone = ifelse(is.na(czone), backfill_czone, czone)) %>%
  select(-backfill_czone)


# Extract first digit and first two digits of business_code
data <- data %>%
  mutate(
    first_digit_business_code = as.factor(substr(business_code, 1, 1)),
    first_two_digits_business_code = as.factor(substr(business_code, 1, 2))
  )

# Filter out rows with missing key variables
data <- data %>%
  filter(complete.cases(fips, state_abbr, first_two_digits_business_code, ins_prsn_covered_eoy_cnt, year, czone, month))


match_result <- matchit(
    formula = missing_iv_var ~ ins_prsn_covered_eoy_cnt,
    exact = ~ year + month + first_two_digits_business_code + czone,
    data = data,
    method = "nearest",
    distance = "mahalanobis",
    replace = TRUE,
    verbose = TRUE,
    discard = "none",
    m.order = "random"
  )

# Get indices of matched pairs
i <- as.numeric(row.names(match_result$match.matrix))
k <- as.numeric(match_result$match.matrix)

# Impute missing IV values
data$iv_var_dm[i] <- data$iv_var_dm[k]

# Impute missing naic_code
data$naic_code[i] <- data$naic_code[k]
data$naic_code_missing <- 0
data$naic_code_missing[i] <- 1

data$ins_iv_var <- data$iv_var_dm


# Save the prepared data
save(data, file = file.path(interm_dir, "prepared_data_for_analysis.RData"))

# nolint end

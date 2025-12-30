# nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.

# Clear workspace
rm(list = ls())
options(width = 200)

set.seed(42)

# Load required libraries
library(data.table)
library(tidyverse)
library(DescTools)
library(MatchIt)
library(vtable)
library(haven)
library(fixest)

# Define file paths for project directories
project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")

# Load the prepared dataset
load(file.path(interm_dir, "prepared_data_for_analysis.RData"))

# Configurable base period for IV construction (use most recent complete year)
base_year <- max(data$year)
base_month <- 1

# Get the average of the fully_ratio for each czone-year-month
data <- data %>%
  filter(mixed_d == 0) %>%
  group_by(czone, year, month) %>%
  mutate(fully_ratio_avg = mean(fully_ratio, na.rm = TRUE)) %>%
  ungroup()


# Now de-mean that for each czone
data <- data %>%
  group_by(czone) %>%
  mutate(fully_ratio_avg_centered = fully_ratio_avg - mean(fully_ratio_avg, na.rm = TRUE)) %>%
  ungroup()

data$iv_var <- data$fully_ratio_avg_centered

# Bin iv_var (evenly) using base period
bins_data <- data %>%
  filter(year == base_year & month == base_month) %>%
  mutate(iv_var_bins = {
    n_bins <- 10
    bins <- ntile(iv_var, n_bins)
    bin_labels <- sapply(1:n_bins, function(i) {
      bin_range <- range(iv_var[bins == i], na.rm = TRUE)
      paste0("[", bin_range[1], ", ", bin_range[2], "]")
    })
    factor(bins, levels = 1:n_bins, labels = bin_labels)
  }) %>%
  select(ein, iv_var_bins)

# Join bins back to data
data <- data %>%
  left_join(bins_data, by = "ein", relationship = "many-to-many")


# Create centered iv_var using leave-one-out means at base period
data <- data %>%
  filter(year == base_year) %>%
  filter(month == base_month) %>%
  group_by(czone, state_abbr, ins_prsn_covered_eoy_cnt_bins) %>%
  mutate(e_wi_total = sum(fully_ratio, na.rm = TRUE),
  n_wi = n()) %>%
  ungroup()  %>% 
  group_by(state_abbr, ins_prsn_covered_eoy_cnt_bins) %>%
  mutate(e_w_total = sum(fully_ratio, na.rm = TRUE),
  n_w = n()) %>%
  ungroup() %>% 
  mutate(e_wi = (e_wi_total - fully_ratio) / (n_wi - 1), 
    e_w = (e_w_total - fully_ratio) / (n_w - 1),
    e_centered = e_wi - e_w) %>% 
    select(ein, e_centered) %>% 
  right_join(data, by = "ein", relationship = "many-to-many")

# Prepare the dependent variable ----------------------------------------------

# Define the dependent variable
dep_var <- "raw_visitor_counts"

# Prepare the instrumental variables ------------------------------------------

# Define the treatment variable (self-insurance status)
data <- data %>%
  mutate(
    self_insurance_status = fully_ratio
  )

# # Winsorize the dependent variable at the 0.5th and 99.5th percentiles --------
data <- data %>%
  group_by(year, month) %>%
  mutate(
    !!dep_var := pmin(
      pmax(get(dep_var), quantile(get(dep_var), 0.005, na.rm = TRUE)),
      quantile(get(dep_var), 0.995, na.rm = TRUE)
    )
  ) %>%
  ungroup()


data_balanced <- data



mod_iv <- feols(
raw_visitor_counts ~ -1 |
    year_month_czone + year_month_two_digit + year_month_bins + ein|
    fully_ratio ~ e_centered,
  cluster = ~ ein,
  data = data_balanced
)

summary(mod_iv)


summary(mod_iv, stage = 1)

dat_1 <- filter(data_balanced, year == base_year & month == base_month) 

mod_1 <- feols(
  fully_ratio ~ e_centered |
    year_month_state + year_month_two_digit + year_month_bins,
  cluster = ~ ein,
  data = dat_1
)
summary(mod_1)

save(data_balanced, file = file.path(interm_dir, "data_balanced_pre_analysis.RData"))

# nolint end
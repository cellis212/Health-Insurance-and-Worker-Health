# nolint start: line_length_linter, trailing_whitespace_linter.

# Clear workspace
rm(list = ls())
options(width = 200)
# Load required libraries
library(fixest)
library(ggplot2)
library(tidyverse)

# Define file paths for project directories
project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")
output_dir <- "../Result/reg results"

# # Load in the state-iv data
# load(file.path(interm_dir, "prepared_data_for_analysis.RData"))
# data_state <- data %>% select(year, month, ein, iv_var, iv_var_pre_2020)


# Load the prepared data
load(file.path(interm_dir, "prepared_data_for_analysis_ins_level_iv.RData"))

# Merge the state-level and insurance-level data
# data <- data %>%
#   inner_join(data_state, by = c("year", "month", "ein"), suffix = c("", "_state"))

data <- data %>%
  filter(!is.na(ins_prsn_covered_eoy_cnt_bins) &
    !is.na(iv_var_pre_2020) &
    !is.na(dwell_more_4h))

# data <- data %>% filter(ins_prsn_2019 < 1000)
data <- data %>% filter(ins_prsn_2019 > 223)
data$ins_prsn_covered_eoy_cnt_bins <- factor(data$ins_prsn_covered_eoy_cnt_bins)

data$iv_did <- data$iv_var_pre_2020 * data$post_covid
# data$iv_did_state <- data$iv_var_pre_2020_state * data$post_covid



# year-month-fips FE
data$year_month_state <- factor(paste(data$year, data$month, data$fips))
# dwell_more_4h
# raw_visitor_counts


data <- data %>% filter(mixed_d != 1)
# data <- data %>% filter(missing == 0)

# # Winsorize the dep vars within month-year
# data <- data %>%
#   group_by(year, month) %>%
#   mutate(
#     dwell_more_4h = ifelse(dwell_more_4h > quantile(dwell_more_4h, 0.99, na.rm = TRUE), quantile(dwell_more_4h, 0.99, na.rm = TRUE), dwell_more_4h),
#     raw_visitor_counts = ifelse(raw_visitor_counts > quantile(raw_visitor_counts, 0.99, na.rm = TRUE), quantile(raw_visitor_counts, 0.99, na.rm = TRUE), raw_visitor_counts)
#   ) %>%
#   ungroup()


mod <- feols(
  I(dwell_more_4h) ~ 1|
    year_month_state + ein|
    did_fully_2020 ~ iv_did:ins_prsn_covered_eoy_cnt_bins,
  data = data,
  cluster = "ein"
)

summary(mod, stage = 1)
summary(mod)

mod <- feols(
  I(raw_visitor_counts) ~ 1 |
    year_month + ein |
    did_fully_2020 ~ iv_did:ins_prsn_covered_eoy_cnt_bins,
  data = data,
  cluster = "ein"
)

summary(mod)


# num obs, f-stat, coef first, coef second, p-second
# other ivs, geog, interactions, logs second stage, log iv, non-averaged

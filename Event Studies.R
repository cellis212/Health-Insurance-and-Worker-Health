# nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.

# Clear workspace
rm(list = ls())

# Load libraries
library(tidyverse)
library(fixest)
library(haven)
library(MatchIt)
library(ggfixest)

# Source the Functions_and_Options.R file, which contains figure_path and table_path
source("Functions_and_Options.R")

# Set random seed
set.seed(42)

# Define file paths
project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")

# Load cleaned data
load(file.path(interm_dir, "data_balanced_pre_analysis_cleaned.RData"))

# Event Study: Linear model
mod_visitor <- feols(
  raw_visitor_counts ~ i(event_time_fac, ins_status_2020_jan, ref = -1) |
    year_month_state + year_month_two_digit + ein,
  cluster = ~ ein,
  data = data_balanced
)
summary(mod_visitor)

# Save plot of coefficients
png(filename = file.path(figure_path, "mod_visitor.png"))
iplot(
  mod_visitor,
  ci_level = 0.9,
  zero = TRUE,
  xlab = "Months to March 2020",
  main = "",
  pt.join = TRUE,
  ci.col = "blue",
  ci.lty = 2,
  xlim = c(7, 35)
)
dev.off()

# Event Study: Log-transformed model
mod_visitor_log <- feols(
  I(log(raw_visitor_counts + 1)) ~ i(event_time_fac, ins_status_2020_jan, ref = -1) |
    year_month_state + year_month_two_digit + ein,
  cluster = ~ ein + naic_code,
  data = data_balanced
)
summary(mod_visitor_log)

png(filename = file.path(figure_path, "mod_visitor_log.png"))
iplot(
  mod_visitor_log,
  geom_style = "errorbar",
  ci_level = 0.9,
  zero = TRUE,
  xlab = "Months to March 2020",
  main = "",
  pt.join = TRUE,
  ci.col = "blue",
  ci.lty = 2,
  xlim = c(7, 35)
)
dev.off()

# IV Event Study: Linear model
mod_visitor_IV <- feols(
  raw_visitor_counts ~ 1 |
    year_month_state + year_month_two_digit + ein |
    i(event_time_fac, ins_status_2020_jan, ref = -1) ~
    I(log(linsurer_otstAMLR_LARGEGROUP)):event_time_fac +
    I(log(linsurer_otstAMLR_LARGEGROUP)):I(log(ins_prsn_2019)):event_time_fac,
  cluster = ~ ein,
  data = data_balanced
)
summary(mod_visitor_IV)

png(filename = file.path(figure_path, "mod_visitor_IV.png"))
iplot(
  mod_visitor_IV,
  ci_level = 0.9,
  zero = TRUE,
  xlab = "Months to March 2020",
  main = "",
  pt.join = TRUE,
  ci.col = "blue",
  ci.lty = 2,
  xlim = c(7, 35)
)
dev.off()

# IV Event Study: Log-transformed model
mod_visitor_log_IV <- feols(
  I(log(raw_visitor_counts + 1)) ~ 1 |
    year_month_state + year_month_two_digit + ein |
    i(event_time_fac, ins_status_2020_jan, ref = -1) ~
      I(log(linsurer_otstAMLR_LARGEGROUP)):event_time_fac +
      I(log(linsurer_otstAMLR_LARGEGROUP)):I(log(ins_prsn_2019)):event_time_fac,
  cluster = ~ ein,
  data = data_balanced
)
summary(mod_visitor_log_IV)

png(filename = file.path(figure_path, "mod_visitor_log_IV.png"))
iplot(
  mod_visitor_log_IV,
  ci_level = 0.9,
  zero = TRUE,
  xlab = "Months to March 2020",
  main = "",
  pt.join = TRUE,
  ci.col = "blue",
  ci.lty = 2,
  xlim = c(7, 35)
)
dev.off()

# nolint end
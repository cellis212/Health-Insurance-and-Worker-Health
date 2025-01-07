# nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.

# Load required libraries
library(fixest)
library(tidyverse)

# Clear workspace
rm(list = ls())

# Define file paths for project directories
project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")

# Source the Functions_and_Options.R file, which contains figure_path and table_path
source("Functions_and_Options.R")

# Load cleaned data
load(file.path(interm_dir, "data_balanced_pre_analysis.RData"))

# # Create a variable for January 2020 minus January 2019
# temp_data_2020 <- data_balanced %>%
#   filter(year == 2020 & month == 1) %>%
#   select(ein, linsurer_otstAMLR_LARGEGROUP) %>%
#   rename(mlr_2020 = linsurer_otstAMLR_LARGEGROUP)

# temp_data_2019 <- data_balanced %>%
#   filter(year == 2019 & month == 1) %>%
#   select(ein, linsurer_otstAMLR_LARGEGROUP) %>%
#   rename(mlr_2019 = linsurer_otstAMLR_LARGEGROUP)

# temp_data_diff <- left_join(temp_data_2020, temp_data_2019, by = "ein") %>%
#   mutate(linsurer_otstAMLR_LARGEGROUP = mlr_2020 / mlr_2019) %>%
#   select(ein, linsurer_otstAMLR_LARGEGROUP)

# data_balanced <- left_join(data_balanced, temp_data_diff, by = "ein")

# Set random seed for reproducibility
set.seed(42)

# Balance the panel data and ensure same sample for OLS and IV
data_balanced <- data_balanced %>%
  group_by(ein) %>%
  filter(n() == 44) %>%
  ungroup() %>%
  filter(mixed_d == 0) %>%
  filter(!is.na(linsurer_otstAMLR_LARGEGROUP),
         !is.na(ins_prsn_2019))

save(data_balanced, file = file.path(interm_dir, "data_balanced_pre_analysis_cleaned.RData"))

# Difference-in-Differences Models --------------------------------------------

# Log-transformed DiD model for raw_visitor_counts
mod_visitor_log_DiD <- feols(
  I(log(raw_visitor_counts + 1)) ~ did_fully_2020 |
    year_month_state + year_month_two_digit + ein,
  cluster = ~ ein,
  data = data_balanced
)

# IV DiD model for raw_visitor_counts
mod_visitor_log_DiD_IV <- feols(
  I(log(raw_visitor_counts + 1)) ~ 1 |
    year_month_state + year_month_two_digit + ein |
    did_fully_2020 ~ I(log(linsurer_otstAMLR_LARGEGROUP)):post_covid +
    I(log(linsurer_otstAMLR_LARGEGROUP)):I(log(ins_prsn_2019)):post_covid,
  cluster = ~ ein,
  data = data_balanced
)
summary(mod_visitor_log_DiD_IV, stage = 1)

# Log-transformed DiD model for raw_visit_counts
mod_visit_log_DiD <- feols(
  I(log(raw_visit_counts + 1)) ~ did_fully_2020 |
    year_month_state + year_month_two_digit + ein,
  cluster = ~ ein,
  data = data_balanced
)

# IV DiD model for raw_visit_counts
mod_visit_log_DiD_IV <- feols(
  I(log(raw_visit_counts + 1)) ~ 1 |
    year_month_state + year_month_two_digit + ein |
    did_fully_2020 ~ I(log(linsurer_otstAMLR_LARGEGROUP)):post_covid +
    I(log(linsurer_otstAMLR_LARGEGROUP)):I(log(ins_prsn_2019)):post_covid,
  cluster = ~ ein,
  data = data_balanced
)

# Log-transformed DiD model for dwell_more_4h
mod_dwell_log_DiD <- feols(
  I(log(dwell_more_4h + 1)) ~ did_fully_2020 |
    year_month_state + year_month_two_digit + ein,
  cluster = ~ ein,
  data = data_balanced
)

# IV DiD model for dwell_more_4h
mod_dwell_log_DiD_IV <- feols(
  I(log(dwell_more_4h + 1)) ~ 1 |
    year_month_state + year_month_two_digit + ein |
    did_fully_2020 ~ I(log(linsurer_otstAMLR_LARGEGROUP)):post_covid +
    I(log(linsurer_otstAMLR_LARGEGROUP)):I(log(ins_prsn_2019)):post_covid,
  cluster = ~ ein,
  data = data_balanced
)

# Table of Results ------------------------------------------------------------

# Helper function to add stars based on p-value, wrapped in $
add_stars <- function(coef, se) {
  p_value <- 2 * (1 - pnorm(abs(coef / se)))
  stars <- case_when(
    p_value < 0.01 ~ "^{***}",
    p_value < 0.05 ~ "^{**}",
    p_value < 0.1 ~ "^{*}",
    TRUE ~ ""
  )
  return(paste0(sprintf('%.3f', coef), stars))
}

# Extract coefficients and standard errors
extract_estimates <- function(model, coef_name) {
  coef_est <- coef(model)[[coef_name]]
  se_est <- se(model)[[coef_name]]
  list(coef = coef_est, se = se_est)
}

# Model estimates for Visitors
est_visitors      <- extract_estimates(mod_visitor_log_DiD, "did_fully_2020")
est_visitors_iv   <- extract_estimates(mod_visitor_log_DiD_IV, "fit_did_fully_2020")

# Model estimates for Visits
est_visits        <- extract_estimates(mod_visit_log_DiD, "did_fully_2020")
est_visits_iv     <- extract_estimates(mod_visit_log_DiD_IV, "fit_did_fully_2020")

# Model estimates for Dwell Time
est_dwell         <- extract_estimates(mod_dwell_log_DiD, "did_fully_2020")
est_dwell_iv      <- extract_estimates(mod_dwell_log_DiD_IV, "fit_did_fully_2020")

# First Table: OLS DiD Results
cat("
\\begin{tabular}{@{\\extracolsep{2pt}}lD{.}{.}{-3}D{.}{.}{-3}D{.}{.}{-3}}
\\toprule
 & \\multicolumn{1}{c}{Visitors} & \\multicolumn{1}{c}{Visits} & \\multicolumn{1}{c}{Dwell Time} \\\\
\\midrule
COVID-19 $\\times$ Fully-Insured &
", add_stars(est_visitors$coef, est_visitors$se), " &
", add_stars(est_visits$coef, est_visits$se), " &
", add_stars(est_dwell$coef, est_dwell$se), " \\\\
& (", sprintf('%.3f', est_visitors$se), ") &
  (", sprintf('%.3f', est_visits$se), ") &
  (", sprintf('%.3f', est_dwell$se), ") \\\\
\\midrule
Year-Month-State FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
Year-Month-Industry FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
Firm FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
\\addlinespace
Observations & \\multicolumn{1}{c}{", formatC(nobs(mod_visitor_log_DiD), format='f', big.mark=',', digits=0), "} & \\multicolumn{1}{c}{", formatC(nobs(mod_visit_log_DiD), format='f', big.mark=',', digits=0), "} & \\multicolumn{1}{c}{", formatC(nobs(mod_dwell_log_DiD), format='f', big.mark=',', digits=0), "} \\\\
\\bottomrule
\\end{tabular}",
file = paste0(table_path, "DiD_ols_results.tex"))

# Second Table: IV DiD Results
cat("
\\begin{tabular}{@{\\extracolsep{2pt}}lD{.}{.}{-3}D{.}{.}{-3}D{.}{.}{-3}}
\\toprule
 & \\multicolumn{1}{c}{Visitors (IV)} & \\multicolumn{1}{c}{Visits (IV)} & \\multicolumn{1}{c}{Dwell Time (IV)} \\\\
\\midrule
COVID-19 $\\times$ Fully-Insured &
", add_stars(est_visitors_iv$coef, est_visitors_iv$se), " &
", add_stars(est_visits_iv$coef, est_visits_iv$se), " &
", add_stars(est_dwell_iv$coef, est_dwell_iv$se), " \\\\
& (", sprintf('%.3f', est_visitors_iv$se), ") &
  (", sprintf('%.3f', est_visits_iv$se), ") &
  (", sprintf('%.3f', est_dwell_iv$se), ") \\\\
\\midrule
Year-Month-State FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
Year-Month-Industry FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
Firm FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
\\addlinespace
Observations & \\multicolumn{1}{c}{", formatC(nobs(mod_visitor_log_DiD_IV), format='f', big.mark=',', digits=0), 
"} & \\multicolumn{1}{c}{", formatC(nobs(mod_visit_log_DiD_IV), format='f', big.mark=',', digits=0), 
"} & \\multicolumn{1}{c}{", formatC(nobs(mod_dwell_log_DiD_IV), format='f', big.mark=',', digits=0), "} \\\\
KP First-stage F & 
\\multicolumn{1}{c}{", sprintf('%.1f', fitstat(mod_visitor_log_DiD_IV, 'ivwald', simplify = TRUE)[1]), 
"} & \\multicolumn{1}{c}{", sprintf('%.1f', fitstat(mod_visit_log_DiD_IV, 'ivwald', simplify = TRUE)[1]), 
"} & \\multicolumn{1}{c}{", sprintf('%.1f', fitstat(mod_dwell_log_DiD_IV, 'ivwald', simplify = TRUE)[1]), "} \\\\

\\bottomrule
\\end{tabular}",
file = paste0(table_path, "DiD_iv_results.tex"))

# LaTeX code to be printed to screen for OLS table
cat("
\\begin{table}[htbp]
    \\centering
    \\begin{threeparttable}
        \\caption{Difference-in-Differences Results (OLS)}
        \\label{tab:DiD_ols_results}
\\input{./tables/DiD_ols_results.tex}
\\begin{tablenotes}
            \\footnotesize
            \\item * p < 0.1, ** p < 0.05, *** p < 0.01.
            \\item Notes: The table reports OLS estimates of the log-transformed dependent variables on the interaction term of COVID-19 and Fully-Insured indicator. All models include firm fixed effects, year-month-state fixed effects, and year-month-industry fixed effects. Standard errors are clustered at the firm level.
        \\end{tablenotes}
    \\end{threeparttable}
\\end{table} \n"
)

# LaTeX code to be printed to screen for IV table
cat("
\\begin{table}[htbp]
    \\centering
    \\begin{threeparttable}
        \\caption{Difference-in-Differences Results (IV)}
        \\label{tab:DiD_iv_results}
\\input{./tables/DiD_iv_results.tex}
\\begin{tablenotes}
            \\footnotesize
            \\item * p < 0.1, ** p < 0.05, *** p < 0.01.
            \\item Notes: The table reports IV estimates of the log-transformed dependent variables on the interaction term of COVID-19 and Fully-Insured indicator. All models include firm fixed effects, year-month-state fixed effects, and year-month-industry fixed effects. Standard errors are clustered at the firm level.
        \\end{tablenotes}
    \\end{threeparttable}
\\end{table}
\n"
)

# nolint end




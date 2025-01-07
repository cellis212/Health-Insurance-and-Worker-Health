# nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.

# Clear workspace
rm(list = ls())

# Load required libraries
library(tidyverse)
library(fixest)
library(haven)
library(MatchIt)

# Source the Functions_and_Options.R file, which contains figure_path and table_path
source("Functions_and_Options.R")

# Set random seed for reproducibility
set.seed(42)

# Define file paths for project directories
project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")

# Load cleaned data
load(file.path(interm_dir, "data_balanced_pre_analysis_cleaned.RData"))

# Load politics data
politics <- read_csv(file.path(interm_dir, "county_year_dem_Rep_2000_2020.csv"))

# Join politics data
data_balanced <- politics %>%
  filter(year == 2016) %>%
  right_join(data_balanced, by = c("county_fips" = "fips"), suffix = c(".x", ""))

# Load collective bargaining data
cb_data <- read_csv(file.path(interm_dir, "step_1_f_5500_99_20_collective_bargain_ind.csv")) %>% 
  mutate(cb_ind = ifelse(is.na(collective_bargain_ind), 0, collective_bargain_ind),
  ein = as.character(spons_dfe_ein))

# Join collective bargaining indicator
data_balanced <- data_balanced %>%
  left_join(cb_data, by = c("ein", "year"))

# IV Difference-in-Differences Model with Original IV -----------------------------
mod_visitor_log_DiD_IV_interact_cb_ind <- feols(
  I(log(raw_visitor_counts + 1)) ~ 1 |
    year_month_state + year_month_two_digit + ein |
  did_fully + did_fully:cb_ind ~ I(log(linsurer_otstAMLR_LARGEGROUP))*I(log(ins_prsn_2019))*post_covid*cb_ind,
  cluster = ~ ein,
  data = data_balanced
)

mod_visitor_log_DiD_IV_interact_dem <- feols(
  I(log(raw_visitor_counts + 1)) ~ 1 |
    year_month_state + year_month_two_digit + ein |
  did_fully + did_fully:ratio_dem2rep ~ I(log(linsurer_otstAMLR_LARGEGROUP))*I(log(ins_prsn_2019))*post_covid*ratio_dem2rep,
  cluster = ~ ein,
  data = data_balanced
)

mod_visitor_log_DiD_IV_interact_dem_win <- feols(
  I(log(raw_visitor_counts + 1)) ~ 1 |
    year_month_state + year_month_two_digit + ein |
  did_fully + did_fully:dem_win ~ I(log(linsurer_otstAMLR_LARGEGROUP))*I(log(ins_prsn_2019))*post_covid*dem_win,
  cluster = ~ ein,
  data = data_balanced
)

# Helper function to add stars based on p-value
add_stars <- function(coef, se) {
  p_value <- 2 * (1 - pnorm(abs(coef / se)))
  stars <- case_when(
    p_value < 0.01 ~ '^{***}',
    p_value < 0.05 ~ '^{**}',
    p_value < 0.1 ~ '^{*}',
    TRUE ~ ''
  )
  return(paste0(sprintf('%.3f', coef), stars))
}

extract_estimates <- function(model, coef_names) {
  estimates <- list()
  for (coef_name in coef_names) {
    coef_est <- coef(model)[[coef_name]]
    se_est <- se(model)[[coef_name]]
    estimates[[coef_name]] <- list(coef = coef_est, se = se_est)
  }
  return(estimates)
}

# Create sets of coefficients for the three columns:
estimates_1 <- extract_estimates(
  mod_visitor_log_DiD_IV_interact_dem,
  c("fit_did_fully", "fit_did_fully:ratio_dem2rep")
)
estimates_2 <- extract_estimates(
  mod_visitor_log_DiD_IV_interact_dem_win,
  c("fit_did_fully", "fit_did_fully:dem_win")
)
estimates_3 <- extract_estimates(
  mod_visitor_log_DiD_IV_interact_cb_ind,
  c("fit_did_fully", "fit_did_fully:cb_ind")
)

# Print the reduced table (removing deaths/cases, adding collective bargaining)
cat("
\\begin{tabular}{@{\\extracolsep{2pt}}lccc}
\\toprule
 & \\multicolumn{1}{c}{(1)} & \\multicolumn{1}{c}{(2)} & \\multicolumn{1}{c}{(3)} \\\\
\\midrule
\\textbf{Dependent Variable:} & \\multicolumn{3}{c}{\\ln(Visitors)} \\\\
\\midrule
COVID-19 x Fully-Insured (fit) & ",
add_stars(estimates_1$fit_did_fully$coef, estimates_1$fit_did_fully$se), " & ",
add_stars(estimates_2$fit_did_fully$coef, estimates_2$fit_did_fully$se), " & ",
add_stars(estimates_3$fit_did_fully$coef, estimates_3$fit_did_fully$se), " \\\\ 
& (", sprintf('%.3f', estimates_1$fit_did_fully$se), ") & (",
      sprintf('%.3f', estimates_2$fit_did_fully$se), ") & (",
      sprintf('%.3f', estimates_3$fit_did_fully$se), ") \\\\
\\addlinespace
\\quad x Ratio Dem/Rep & ",
add_stars(estimates_1$`fit_did_fully:ratio_dem2rep`$coef, estimates_1$`fit_did_fully:ratio_dem2rep`$se), " & & \\\\
& (", sprintf('%.3f', estimates_1$`fit_did_fully:ratio_dem2rep`$se), ") & & \\\\
\\quad x Democrat Win & & ",
add_stars(estimates_2$`fit_did_fully:dem_win`$coef, estimates_2$`fit_did_fully:dem_win`$se), " & \\\\
& & (", sprintf('%.3f', estimates_2$`fit_did_fully:dem_win`$se), ") & \\\\
\\quad x Collective Bargaining & & & ",
add_stars(estimates_3$`fit_did_fully:cb_ind`$coef, estimates_3$`fit_did_fully:cb_ind`$se), " \\\\
& & & (", sprintf('%.3f', estimates_3$`fit_did_fully:cb_ind`$se), ") \\\\
\\midrule
Year-Month-State FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
Year-Month-Industry FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
Firm FEs: & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} & \\multicolumn{1}{c}{Yes} \\\\
\\midrule
KP First-stage F & ",
sprintf('%.1f', fitstat(mod_visitor_log_DiD_IV_interact_dem, 'ivwald', simplify = TRUE)[1]), " & ",
sprintf('%.1f', fitstat(mod_visitor_log_DiD_IV_interact_dem_win, 'ivwald', simplify = TRUE)[1]), " & ",
sprintf('%.1f', fitstat(mod_visitor_log_DiD_IV_interact_cb_ind, 'ivwald', simplify = TRUE)[1]), " \\\\
Observations & ", 
formatC(nobs(mod_visitor_log_DiD_IV_interact_dem), format='f', big.mark=',', digits=0), " & ",
formatC(nobs(mod_visitor_log_DiD_IV_interact_dem_win), format='f', big.mark=',', digits=0), " & ",
formatC(nobs(mod_visitor_log_DiD_IV_interact_cb_ind), format='f', big.mark=',', digits=0), " \\\\
\\bottomrule
\\end{tabular}",
file = paste0(table_path, "DiD_results_interact_cb.tex"))

cat("
\\begin{table}[htbp]
    \\centering
    \\begin{threeparttable}
        \\caption{Title}
        \\label{tab:title}
\\input{./tables/DiD_results_interact_cb.tex}
\\begin{tablenotes}
            \\footnotesize
            \\item \\textbf{Notes:} $^{*} p < 0.1, ^{**} p < 0.05, ^{***} p < 0.01$. Standard errors are clustered by firm and industry code. Collective bargaining indicator is interacted to assess differences in the fully-insured effect.
        \\end{tablenotes}
    \\end{threeparttable}
\\end{table} \n"
)

# nolint end




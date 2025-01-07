# nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.

# Clear workspace
rm(list = ls())

# Load required libraries
library(fixest)
library(dplyr)
library(haven)
library(ggplot2)
library(MatchIt)
library(tidyverse)

# Set random seed for reproducibility
set.seed(42)

# Define file paths for project directories
project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")
output_dir <- "../Result/reg results"
table_path <- "../Result/tables/"

# Read the data
load(file.path(interm_dir, "prepared_data_for_analysis_ins_level_iv.RData"))

# Set the preferred IV variables
IV_Variables <- c("iv_var", "linsurer_otstAMLR_LARGEGROUP")  # Preferred specification

# Data cleaning and preparation -----------------------------------------------

# Filter data for complete cases of key variables
data <- data %>%
  filter(
    !is.na(ins_prsn_covered_eoy_cnt_bins) &
    !is.na(dwell_more_4h)
  )

# Extract first digit and first two digits of business_code
data <- data %>%
  mutate(
    first_digit_business_code = as.factor(substr(business_code, 1, 1)),
    first_two_digits_business_code = as.factor(substr(business_code, 1, 2))
  )

# Create num_covered_2020 variable
data <- data %>%
  group_by(ein) %>%
  mutate(
    num_covered_2020 = ifelse(year == 2020, all_INS_PRSN_COVERED_EOY_CNT, NA)
  ) %>%
  fill(num_covered_2020, .direction = "updown") %>%
  ungroup()

# Create interaction variables
data <- data %>%
  mutate(
    year_month = factor(paste(year, month)),
    year_month_state = factor(paste(year, month, state_abbr)),
    year_month_czone = factor(paste(year, month, czone)),
    year_month_bins = factor(paste(year, month, ins_prsn_covered_eoy_cnt_bins))
  )

# Create 'state_year_month_two_digit' variable
data <- data %>%
  mutate(
    state_year_month_two_digit = factor(paste(state_abbr, year, month, first_two_digits_business_code))
  )

# Matching to impute missing IV values ----------------------------------------

# Create binary indicator if any IV variable is missing
data <- data %>%
  mutate(
    missing_iv_var = if_else(
      rowSums(is.na(select(., all_of(IV_Variables))) | select(., all_of(IV_Variables)) == "") > 0,
      1, 0
    )
  )

# Perform matching if there are missing IV values
if (any(data$missing_iv_var == 1)) {
  # Prepare data for matching
  match_data <- data %>%
    filter(complete.cases(fips, state_abbr, manufacturing_dummy, ins_prsn_covered_eoy_cnt, year))

  # Apply matchit to impute missing IV values
  match_result <- matchit(
    formula = missing_iv_var ~ fips + ins_prsn_covered_eoy_cnt + manufacturing_dummy,
    exact = ~ state_abbr + year,
    data = match_data,
    method = "nearest",
    distance = "mahalanobis",
    replace = TRUE,
    verbose = TRUE,
    discard = "none"
  )

  # Get indices of matched pairs
  i <- as.numeric(row.names(match_result$match.matrix))
  k <- as.numeric(match_result$match.matrix)

  # Impute missing IV values for both IV variables
  for (iv_var in IV_Variables) {
    data[[iv_var]][i] <- if_else(
      is.na(data[[iv_var]][i]) | data[[iv_var]][i] == "",
      data[[iv_var]][k],
      data[[iv_var]][i]
    )
  }

  # Impute missing naic_code if necessary
  data$naic_code[i] <- if_else(
    is.na(data$naic_code[i]),
    data$naic_code[k],
    data$naic_code[i]
  )
}

# Prepare dependent variables -------------------------------------------------

dep_vars <- c("raw_visitor_counts", "raw_visit_counts", "dwell_more_4h")

# Calculate pre-period means for dependent variables
data <- data %>%
  group_by(ein) %>%
  mutate(across(
    all_of(dep_vars),
    ~ mean(.x[year < 2020], na.rm = TRUE),
    .names = "{.col}_pre"
  )) %>%
  ungroup()

# Prepare the instrumental variables ------------------------------------------

# Log the IV variables and create interaction terms
for (iv_var in IV_Variables) {
  data <- data %>%
    mutate(
      !!paste0("log_", iv_var) := log(!!sym(iv_var) + 1)
    )
}

# Define the treatment variable
data <- data %>%
  mutate(
    treat = did_fully_2020 
  )

# Create event time variables -------------------------------------------------

# Define event time relative to 2020 (assuming treatment occurs in 2020)
data <- data %>%
  mutate(
    event_time = year - 2020
  )

# Limit event time between -5 and +5 years
data <- data %>%
  filter(event_time >= -5 & event_time <= 5)

# Filter data according to preferred specification ----------------------------

data <- data %>%
  filter(
    mixed_d != 1  # Include observations where mixed_d is not equal to 1
  )

# Winsorize dependent variables at 99th percentile ----------------------------

data <- data %>%
  group_by(year) %>%
  mutate(
    across(
      all_of(dep_vars),
      ~ pmin(
        pmax(.x, quantile(.x, 0.005, na.rm = TRUE)),
        quantile(.x, 0.995, na.rm = TRUE)
      )
    )
  ) %>%
  ungroup()

# Fixed Effects and Clustering ------------------------------------------------

# Define fixed effects
fe_formula <- "year_month_state + ein"

# Define clusters
cluster_vars <- c("ein", "naic_code")

# Initialize a list to store results
event_study_results <- list()

# Loop through dependent variables --------------------------------------------

for (dep_var in dep_vars) {
  # Build the formula for the event study estimation using fixest syntax
  # Include leads and lags of treatment variable (event_time)
  formula <- as.formula(
    paste0(
      dep_var, " ~ i(event_time, treat, ref = -1) | ", fe_formula, " | 0 | ", paste(cluster_vars, collapse = "+")
    )
  )
  
  # Estimate the model
  model <- feols(
    formula,
    data = data,
    vcov = "cluster"
  )
  
  # Store the results
  event_study_results[[dep_var]] <- model
}

# Save the event study results
save(event_study_results, file = file.path(output_dir, "event_study_results.RData"))

# Generate event study plots --------------------------------------------------

# Function to plot event study results
plot_event_study <- function(model, dep_var) {
  # Extract coefficients and confidence intervals
  est <- coefplot(model, keep = "event_time::", plot = FALSE)
  
  # Create the plot
  p <- ggplot(est, aes(x = as.numeric(var), y = coeff)) +
    geom_point() +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2) +
    geom_vline(xintercept = -1, linetype = "dashed", color = "red") +
    labs(
      x = "Event Time",
      y = "Coefficient Estimate",
      title = paste("Event Study Plot for", dep_var)
    ) +
    theme_minimal()
  
  # Save the plot
  ggsave(filename = paste0(output_dir, "/event_study_plot_", dep_var, ".png"), plot = p)
  
  return(p)
}

# Plot and save event study results for each dependent variable
for (dep_var in dep_vars) {
  model <- event_study_results[[dep_var]]
  plot_event_study(model, dep_var)
}

# Create regression tables ----------------------------------------------------

# Helper function to add stars based on p-value
add_stars <- function(coef, se) {
  p_value <- 2 * (1 - pnorm(abs(coef / se)))
  stars <- case_when(
    p_value < 0.01 ~ '***',
    p_value < 0.05 ~ '**',
    p_value < 0.1 ~ '*',
    TRUE ~ ''
  )
  return(paste0(sprintf('%.3f', coef), stars))
}

# Prepare variables for the table
variables <- c("event_time::treat::-5", "event_time::treat::-4", "event_time::treat::-3",
               "event_time::treat::-2", "event_time::treat::0", "event_time::treat::1",
               "event_time::treat::2", "event_time::treat::3", "event_time::treat::4",
               "event_time::treat::5")

# Initialize table content
table_content <- ""

for (var in variables) {
  coef_row <- ""
  se_row <- ""
  for (dep_var in dep_vars) {
    model <- event_study_results[[dep_var]]
    coef_value <- coef(model)[var]
    se_value <- se(model)[var]
    coef_with_stars <- if (!is.na(coef_value)) add_stars(coef_value, se_value) else ""
    se_formatted <- if (!is.na(se_value)) sprintf('%.3f', se_value) else ""
    coef_row <- paste0(coef_row, " & ", coef_with_stars)
    se_row <- paste0(se_row, " & (", se_formatted, ")")
  }
  coef_row <- paste0(var, coef_row, " \\\\")
  se_row <- paste0(" ", se_row, " \\\\")
  table_content <- paste0(table_content, coef_row, "\n", se_row, "\n")
}

# Assemble the table
cat("
\\begin{tabular}{@{\\extracolsep{2pt}}lD{.}{.}{-3} D{.}{.}{-3} D{.}{.}{-3}}
\\toprule
& \\multicolumn{1}{c}{", dep_vars[1], "} & \\multicolumn{1}{c}{", dep_vars[2], "} & \\multicolumn{1}{c}{", dep_vars[3], "} \\\\
\\midrule
", table_content, "
\\midrule
Fixed Effects: & Yes & Yes & Yes \\\\
Clusters: & ein, naic & ein, naic & ein, naic \\\\
\\midrule
Observations & ", formatC(nobs(event_study_results[[dep_vars[1]]]), format='f', big.mark=',', digits=0), " & ",
                   formatC(nobs(event_study_results[[dep_vars[2]]]), format='f', big.mark=',', digits=0), " & ",
                   formatC(nobs(event_study_results[[dep_vars[3]]]), format='f', big.mark=',', digits=0), " \\\\
Within R$^2$ & ", sprintf('%.3f', r2(event_study_results[[dep_vars[1]]])['wr2']), " & ",
                  sprintf('%.3f', r2(event_study_results[[dep_vars[2]]])['wr2']), " & ",
                  sprintf('%.3f', r2(event_study_results[[dep_vars[3]]])['wr2']), " \\\\
\\bottomrule
\\end{tabular}",
file = paste0(table_path, "event_study_results.tex"))

# Sample LaTeX code to include the table --------------------------------------

cat("
\\begin{table}[htbp]
    \\centering
    \\begin{threeparttable}
        \\caption{Event Study Regression Results}
        \\label{tab:event_study_results}
\\input{", table_path, "event_study_results.tex", "}
\\begin{tablenotes}
            \\footnotesize
            \\item * p < 0.1, ** p < 0.05, *** p < 0.01.
            \\item Notes: Standard errors are clustered at the EIN and NAIC code levels.
        \\end{tablenotes}
    \\end{threeparttable}
\\end{table}"
)

# nolint end

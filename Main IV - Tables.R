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
      !!paste0(iv_var, "_did") := log(!!sym(iv_var) + 1) * post_covid
    )
}

# Combine IV interaction terms into a single string for regression
iv_interaction_terms <- paste0(IV_Variables, "_did:first_two_digits_business_code", collapse = " + ")

# Define the treatment variable
data <- data %>%
  mutate(
    treat = did_fully_2020  # Preferred Treatment Variable
  )

# Filter data according to preferred specification ----------------------------

data <- data %>%
  filter(
    mixed_d != 1  # Include observations where mixed_d is not equal to 1
  )

# Winsorize dependent variables at 99th percentile ----------------------------

data <- data %>%
  mutate(
    across(
      all_of(dep_vars),
      ~ pmin(
        pmax(.x, quantile(.x, 0.005, na.rm = TRUE)),
        quantile(.x, 0.995, na.rm = TRUE)
      )
    )
  )

# Fixed Effects and Clustering ------------------------------------------------

# Define fixed effects
fe_formula <- "year_month_state + ein"

# Define clusters
cluster_vars <- c("ein", "naic_code")

# Initialize a list to store results
results <- list()

# Loop through dependent variables --------------------------------------------

for (dep_var in dep_vars) {
  # Build the formula for 2SLS estimation
  iv_formula <- paste("treat ~", iv_interaction_terms)
  dependent_variable <- dep_var
  control_variables <- "1"  # No additional controls
  fixed_effects <- fe_formula

  formula <- as.formula(
    paste(dependent_variable, "~", control_variables, "|", fixed_effects, "|", iv_formula)
  )

  # Estimate the model using the specified clustering
  model <- feols(
    fml = formula,
    data = data,
    cluster = cluster_vars
  )

  # Save the results
  treat_coef <- coef(model)["fit_treat"]
  pre_mean <- mean(data[[paste0(dep_var, "_pre")]], na.rm = TRUE)
  treat_effect <- treat_coef / pre_mean
  ci <- confint(model, level = 0.9)
  ub <- ci["fit_treat", 2] / pre_mean
  lb <- ci["fit_treat", 1] / pre_mean

  # Store the results in the list
  results[[dep_var]] <- list(
    treat_coef = treat_coef,
    pre_mean = pre_mean,
    model = model,
    treat_effect = treat_effect,
    ub = ub,
    lb = lb
  )
}

# Save the model results
save(results, file = file.path(output_dir, "preferred_model.RData"))

# nolint end

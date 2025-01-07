# nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.

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

# Load the prepared dataset
load(file.path(interm_dir, "prepared_data_for_analysis.RData"))

# Data cleaning and preparation -----------------------------------------------

# Create event time variables
data <- data %>%
  mutate(
    event_date = as.Date(paste(year, month, "01", sep = "-"), format = "%Y-%m-%d"),
    treatment_date = as.Date("2020-03-01"),
    event_time = interval(treatment_date, event_date) %/% months(1),
    event_time_fac = as.factor(event_time)
  )

# Extract first digit and first two digits of business_code
data <- data %>%
  mutate(
    first_digit_business_code = as.factor(substr(business_code, 1, 1)),
    first_two_digits_business_code = as.factor(substr(business_code, 1, 2))
  )

# Create num_covered_2020 variable for March 2020
data <- data %>%
  group_by(ein) %>%
  mutate(
    num_covered_2020 = ifelse(year == 2020 & month == 3, all_INS_PRSN_COVERED_EOY_CNT, NA)
  ) %>%
  fill(num_covered_2020, .direction = "updown") %>%
  ungroup()

# Create interaction variables
data <- data %>%
  mutate(
    year_month = factor(paste(year, month)),
    year_month_state = factor(paste(year, month, state_abbr)),
    year_month_czone = factor(paste(year, month, czone)),
    year_month_bins = factor(paste(year, month, ins_prsn_covered_eoy_cnt_bins)),
    year_month_two_digit = factor(paste(year, month, first_two_digits_business_code))
  )

# Matching to impute missing IV values ----------------------------------------
l <- which(is.na(data$linsurer_otstAMLR_LARGEGROUP) & !(is.na(data$naic_code)))
k <- which(!(is.na(data$linsurer_otstAMLR_LARGEGROUP)) & (is.na(data$naic_code)))


# Specify the preferred IV variables
IV_Variables <- c("linsurer_otstAMLR_LARGEGROUP")


# Create average pre-2020 iv_var at the firm level
data <- data %>%
  group_by(ein) %>%
  mutate(
    iv_var_2019 = mean(linsurer_otstAMLR_LARGEGROUP[year == 2019], na.rm = TRUE),
    iv_var_2018 = mean(linsurer_otstAMLR_LARGEGROUP[year == 2018], na.rm = TRUE),
    iv_var_pre_2020 = mean(linsurer_otstAMLR_LARGEGROUP[year < 2020], na.rm = TRUE)
  ) %>%
  ungroup() 


# data$linsurer_otstAMLR_LARGEGROUP <- data$iv_var_2019

# Create an indicator for missing IV values
data <- data %>%
  mutate(
    missing_iv_var = if_else(
      is.na(linsurer_otstAMLR_LARGEGROUP), 1, 0
    )
  )


# Filter out rows with missing key variables
data <- data %>%
  filter(complete.cases(fips, state_abbr, first_two_digits_business_code, ins_prsn_covered_eoy_cnt, ins_prsn_covered_eoy_cnt_bins, year))


match_result <- matchit(
    formula = missing_iv_var ~ fips,
    exact = ~ state_abbr + year + month,
    data = data,
    method = "nearest",
    distance = "mahalanobis",
    replace = TRUE,
    verbose = TRUE,
    discard = "none"
  )

# Get indices of matched pairs
i <- as.numeric(row.names(match_result$match.matrix))
k <- as.numeric(match_result$match.matrix)

# Impute missing IV values
data$linsurer_otstAMLR_LARGEGROUP[i] <- data$linsurer_otstAMLR_LARGEGROUP[k]

# Impute missing naic_code
data$naic_code[i] <- data$naic_code[k]

# Create average pre-2020 iv_var at the firm level
data <- data %>%
  group_by(ein) %>%
  mutate(
    iv_var_2019 = mean(iv_var[year == 2019], na.rm = TRUE),
    iv_var_2018 = mean(iv_var[year == 2018], na.rm = TRUE),
    iv_var_pre_2020 = mean(iv_var[year < 2020], na.rm = TRUE)
  ) %>%
  ungroup() %>% 
  mutate(iv_var_increase = iv_var_2019 - iv_var_2018)



# Prepare the dependent variable ----------------------------------------------

# Define the dependent variable
dep_var <- "raw_visitor_counts"

# Calculate pre-period means for the dependent variable
data <- data %>%
  group_by(ein) %>%
  mutate(
    dep_var_pre = mean(get(dep_var)[year < 2020 | (year == 2020 & month < 3)], na.rm = TRUE)
  ) %>%
  ungroup()

# Prepare the instrumental variables ------------------------------------------

# Define the treatment variable
data <- data %>%
  mutate(
    treat = did_fully_2020
  )

# Winsorize the dependent variable at the 0.5th and 99.5th percentiles --------
data <- data %>%
  group_by(year, month) %>%
  mutate(
    !!dep_var := pmin(
      pmax(get(dep_var), quantile(get(dep_var), 0.005, na.rm = TRUE)),
      quantile(get(dep_var), 0.995, na.rm = TRUE)
    )
  ) %>%
  ungroup()

# # Balance the panel data ------------------------------------------------------
# data_balanced <- data %>%
#   group_by(ein) %>%
#   filter(
#     n() == 36
#   ) %>%
#   ungroup()

data_balanced <- data

save(data_balanced, file = file.path(interm_dir, "data_balanced_pre_analysis.RData"))

# nolint end
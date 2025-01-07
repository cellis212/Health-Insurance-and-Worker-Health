# nolint start: line_length_linter, trailing_whitespace_linter.


# Clear workspace 
rm(list = ls())

# Load required libraries
library(fixest)
library(data.table)
library(dplyr)
library(haven)
library(plm)
library(readstata13)
library(MASS)
library(ggplot2)

# Define file paths for project directories
project_dir <- "../Data"
data_dir <- file.path(project_dir, "raw_data/5500/Form_5500")
interm_dir <- file.path(project_dir, "intermediate_data")
output_dir <- "../Result/reg results"

# Read the CSV file containing panel data for OLS and IV regression
data <- fread(file.path(interm_dir, "step_13_panel_for_ols_iv_reg_new.csv"))

# Load the new CSV file with instruments
iv_data <- fread(file.path(interm_dir, "healthpremium_iv_at.csv"))

# Data preprocessing
data <- unique(data, by = c("ein", "year", "month"))  # Remove duplicates

# Create a balanced panel
# data <- data %>%
#   group_by(ein) %>%
#   mutate(obs_count = n()) %>%
#   filter(obs_count >= 44) %>%
#   ungroup()

# Filter to only firms that were fully insured in 2018 or 2019 (but keep all years)
# data <- data %>%
#   group_by(ein) %>%
#   filter((any(year == 2018 & fully_d == 1) | any(year == 2019 & fully_d == 1))) %>%
#   ungroup()

# # Drop firms that ever have mixed insurance
# data <- data %>%
#   group_by(ein) %>%
#   filter(!(any(mixed_d == 1)))

# Create a variable for firms that became self insured by January 2020
data <- data %>%
  group_by(ein) %>%
  mutate(self_insured_2020_jan = as.integer(any(year == 2020 & month == 1 & self_d == 1))) %>%
  ungroup()

# Create a variable for firms that became mixed insured by January 2020
data <- data %>%
  group_by(ein) %>%
  mutate(mixed_insured_2020_jan = as.integer(any(year == 2020 & month == 1 & mixed_d == 1))) %>%
  ungroup()

# Create a variable for firms that became fully insured by January 2020
data <- data %>%
  group_by(ein) %>%
  mutate(fully_insured_2020_jan = as.integer(any(year == 2020 & month == 1 & fully_d == 1))) %>%
  ungroup()

# Create post covid variable (starting from month 3 of 2020)
data <- data %>%
  mutate(post_covid = ifelse(year > 2020 | (year == 2020 & month >= 3), 1, 0))

# Make sure every firm has an observation for pre and post covid
data <- data %>%
  group_by(ein) %>%
  filter(any(post_covid == 1) & any(post_covid == 0)) %>%
  ungroup()

# Create DID variables (self insured in January 2020 * post covid 
# & mixed insured in January 2020 * post covid & fully insured in January 2020 * post covid) 
data <- data %>%
  mutate(did_self = self_insured_2020_jan * post_covid,
         did_mixed = mixed_insured_2020_jan * post_covid,
         did_fully = fully_insured_2020_jan * post_covid)

# Create year-month factor variable
data <- data %>%
  mutate(year_month = as.factor(paste(year, month, sep = "-")))

# Base TWFEs with clustering by firm and year-month fixed effects
# ln(visits)
twfe <- feols(I(log(raw_visit_counts)) ~ did_fully | ein + year_month, 
              data = data, 
              cluster = "ein")
summary(twfe)

# ln(visitors)
twfe <- feols(I(log(raw_visitor_counts)) ~ did_fully | ein + year_month, 
              data = data, 
              cluster = "ein")
summary(twfe)

# ln(dwell 4hr)
twfe <- feols(I(log(dwell_more_4h)) ~ did_fully | ein + year_month, 
              data = data, 
              cluster = "ein")
summary(twfe)



# Create relative treatment time variable
data <- data %>%
  group_by(ein) %>%
  mutate(
    ever_self_insured = as.integer(any(self_d == 1)),
    covid_date = as.Date("2020-04-01"),
    current_date = as.Date(paste(year, month, "01", sep = "-")),
    rel_treat_time = (year - 2020) * 12 + (month - 3),
    rel_treat_time = ifelse(self_insured_2020_jan == 1, rel_treat_time, 0)
  ) %>%
  ungroup()

# Create factor for event time
data <- data %>%
  mutate(
    rel_treat_time_factor = factor(
      rel_treat_time,
      levels = sort(unique(rel_treat_time)),
      ordered = FALSE  # Change this to FALSE
    )
  )

# Relevel the factor to make -1 the reference level
data$rel_treat_time_factor <- relevel(data$rel_treat_time_factor, ref = "-1")

# Event study regressions
# ln(visits)
event_study_visits <- feols(I(log(raw_visit_counts)) ~ rel_treat_time_factor | ein + year_month, 
                     data = data, 
                     cluster = "ein")
summary(event_study_visits)

# ln(visitors)
event_study_visitors <- feols(I(log(raw_visitor_counts)) ~ rel_treat_time_factor | ein + year_month, 
                     data = data, 
                     cluster = "ein")
summary(event_study_visitors)

# ln(dwell 4hr)
event_study_dwell <- feols(I(log(dwell_more_4h)) ~ rel_treat_time_factor | ein + year_month, 
                     data = data, 
                     cluster = "ein")
summary(event_study_dwell)


# Function to plot event study results
plot_event_study <- function(model, title) {
  coef_data <- data.frame(
    time = as.numeric(gsub("rel_treat_time_factor", "", names(coef(model)))),
    estimate = coef(model),
    se = sqrt(diag(vcov(model)))
  )
  
  # Add the reference point (t-1)
  coef_data <- rbind(
    data.frame(time = -1, estimate = 0, se = 0),
    coef_data
  )
  
  # Sort the data frame by time
  coef_data <- coef_data[order(coef_data$time), ]
  
  # Filter data to include only -7 to +10 time periods
  # coef_data <- coef_data[coef_data$time >= -7 & coef_data$time <= 10, ]
  
  ggplot(coef_data, aes(x = time, y = estimate)) +
    geom_point() +
    geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se), width = 0.2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_vline(xintercept = -.5, linetype = "dashed", color = "red") +
    labs(title = title, x = "Relative Time", y = "Coefficient") +
    theme_minimal() 
    # scale_x_continuous(breaks = seq(-7, 10, by = 2)) +
    # coord_cartesian(xlim = c(-7, 10))  # Set x-axis limits
}

# Generate plots
plot_visits <- plot_event_study(event_study_visits, "Event Study: ln(visits)")
plot_visitors <- plot_event_study(event_study_visitors, "Event Study: ln(visitors)")
plot_dwell <- plot_event_study(event_study_dwell, "Event Study: ln(dwell 4hr)")

# Display plots
print(plot_visits)
print(plot_visitors)
print(plot_dwell)

# nolint end
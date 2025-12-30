library(tidyverse)
library(tidycensus)
library(haven)

source("Functions_and_Options.R")

project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")

census_api_key("23bf7af058f8fcc00688049bf3d6f77fdf62934a")
acs_vars <- c(
  # Median household income
  median_income = "B19013_001",
  
  # Race variables - total population by race
  total_pop = "B02001_001",
  white_pop = "B02001_002",
  black_pop = "B02001_003",
  asian_pop = "B02001_005",
  hispanic_pop = "B03002_012"
)

# Get county level data for 2019
acs_data_2019 <- get_acs(
  geography = "county",
  variables = acs_vars,
  year = 2019,
  survey = "acs5",
  geometry = FALSE
) %>%
  # Pivot wider to have one row per county
  pivot_wider(
    id_cols = c(GEOID),
    names_from = variable,
    values_from = estimate
  ) %>%
  # Calculate percentages
  mutate(
    pct_white = white_pop / total_pop * 100,
    pct_black = black_pop / total_pop * 100,
    pct_asian = asian_pop / total_pop * 100,
    pct_hispanic = hispanic_pop / total_pop * 100
  ) %>%
  # Select and rename final variables
  select(
    GEOID,
    median_income,
    total_pop,
    pct_white,
    pct_black,
    pct_asian,
    pct_hispanic
  )

# Save the cleaned data
write_csv(
  acs_data_2019,
  file.path(interm_dir, "county_demographics_2019.csv")
)

# Print summary statistics
summary(acs_data_2019) 
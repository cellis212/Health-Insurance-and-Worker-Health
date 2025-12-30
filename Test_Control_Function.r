# nolint start: line_length_linter, trailing_whitespace_linter.

# Clear the working directory
rm(list = ls())

# Load required packages
library(fixest)
library(ggplot2)
library(dplyr)

# Set seed for reproducibility
set.seed(123)

# Simulation parameters
n <- 1000  # number of observations
T <- 2     # number of time periods

# Generate data
simulate_data <- function(n, T) {
  # Generate instrument
  iv <- rnorm(n)
  
  # Generate error terms with correlation
  u <- rnorm(n)
  e <- 0.7 * u + 0.3 * rnorm(n)  # Introduce correlation between u and e
  
  # Generate endogenous treatment
  treat_prob <- pnorm(0.5 * iv + 0.5 * u)
  treat_group <- rbinom(n, 1, treat_prob)
  
  # Expand data for two time periods
  data <- data.frame(
    id = rep(1:n, each = T),
    time = rep(0:1, n),
    iv = rep(iv, each = T),
    treat_group = rep(treat_group, each = T)
  )
  
  # Generate post indicator
  data$post <- data$time == 1
  
  # Generate outcome
  data$y <- 2 + 3 * data$treat_group + 2 * data$post + 
            4 * data$treat_group * data$post + 
            0.5 * rep(u, each = T) + rep(e, each = T)
  
  return(data)
}

# Simulate data
sim_data <- simulate_data(n, T)

# Base model (biased due to endogeneity)
base_model <- feols(y ~ treat_group * post | time, data = sim_data)

# Control Function Approach (Residual Inclusion)
first_stage <- feols(treat_group ~ iv, data = sim_data)
sim_data$residuals <- residuals(first_stage)

cf_model <- feols(y ~ treat_group * post + residuals + treat_group | time, data = sim_data)

# 2SLS Approach
iv_formula <- y ~ 1 | time | treat_group + treat_group:post ~ iv + iv:post

iv_model <- feols(iv_formula, data = sim_data)

# Print results
cat("Base Model Results (Biased):\n")
print(summary(base_model))

cat("\nControl Function Approach Results:\n")
print(summary(cf_model))

cat("\n2SLS Approach Results:\n")
print(summary(iv_model))

# Save results
# save(sim_data, cf_model, iv_model, file = "simulation_results.RData")

# nolint end

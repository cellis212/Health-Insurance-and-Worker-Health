# nolint start: line_length_linter, trailing_whitespace_linter.

# Pre-amble ---------------------------------------------------------------

# Clearing Memory
rm(list = ls())

# Loading Packages
library(tidyverse)
library(fixest)
library(foreach)
library(doParallel)
library(MatchIt)

# Set Seed
set.seed(42)

# Setup parallel processing
cores <- detectCores() - 1
cl <- makeCluster(cores)
registerDoParallel(cl)

# Loading Data ------------------------------------------------------------
load("../Data/intermediate_data/prepared_data_for_analysis_ins_level_iv.RData")

# Set the IV variable
IV_Variable <- "linsurer_otst_mlr" # Ensure this is a single string, not a vector

# Data Cleaning -----------------------------------------------------------
data <- data %>%
  filter(!is.na(ins_prsn_covered_eoy_cnt_bins) &
    !is.na(dwell_more_4h))

data$year_month_state <- factor(paste(data$year, data$month, data$state_abbr))
data$year_month_fips <- factor(paste(data$year, data$month, data$fips))
data$year_month_czone <- factor(paste(data$year, data$month, data$czone))

# Matching stuff ----------------------------------------------------------
# Create a binary treatment variable for matching
data <- data %>%
  mutate(missing = case_when(
    is.na(.data[[IV_Variable]]) ~ 1,
    .data[[IV_Variable]] == "" ~ 1,
    TRUE ~ 0
  ))

summary(data$missing)


if (max(data$missing) != 0) {
  # Filter to complete cases for the covariates used in matchit
  data <- data %>% filter(complete.cases(fips, state_abbr, manufacturing_dummy, ins_prsn_covered_eoy_cnt, year))

  # Apply matchit to get predicted insurer for self insured
  match_data <- matchit(
    formula = missing ~ fips + ins_prsn_covered_eoy_cnt + manufacturing_dummy,
    exact = ~ state_abbr + year,
    data = data,
    method = "nearest",
    distance = "mahalanobis",
    replace = TRUE,
    verbose = TRUE,
    discard = "none"
  )

  # Get indices of matched pairs
  i <- match_data$match.matrix %>%
    row.names() %>%
    as.character() %>%
    as.numeric()

  k <- match_data$match.matrix %>%
    as.character() %>%
    as.numeric()


  data[[IV_Variable]][i] <- ifelse(is.na(data[[IV_Variable]][i]), data[[IV_Variable]][k], data[[IV_Variable]][i])
}




# Options -----------------------------------------------------------------
Fixed_Effects <- c("year_month + ein", 
"year_month + state_abbr + ein") # Option for fixed effects
Interact_Instrument <- c("Yes") # Option to interact the IV with the bin variable
Drop_Low <- c(0, 1, 2, 3) # Option for dropping bottom bins
Drop_High <- c(0) # Option for dropping top bins
Drop_Mixed <- c(FALSE) # Option for dropping mixed_d == 1
Log_IV <- c(FALSE, TRUE) # Option for logging the IV variable
Log_DV <- c(FALSE, TRUE) # Option for logging the dependent variable
Cluster_By <- c("ein + naic_code") # Option for clustering
Winsorize_IV <- c("None", "99", "95") # Option for winsorizing IV
Winsorize_DV <- c("None", "99", "95") # Option for winsorizing dependent variable
Matching <- c(TRUE) # Option for matching

# This creates all combinations of your options
Models <- expand.grid(
  Fixed_Effects = Fixed_Effects,
  Interact_Instrument = Interact_Instrument,
  Drop_Low = Drop_Low,
  Drop_High = Drop_High,
  Drop_Mixed = Drop_Mixed,
  IV_Variable = IV_Variable,
  Log_IV = Log_IV,
  Log_DV = Log_DV,
  Cluster_By = Cluster_By,
  Winsorize_IV = Winsorize_IV,
  Winsorize_DV = Winsorize_DV,
  Matching = Matching
)

# Create columns for the things to save
Models$treat <- 0
Models$fstat <- 0
Models$num_obs <- 0
Models$num_pos_sig_first <- 0
Models$num_neg_sig_first <- 0
Models$coef_second <- 0
Models$p_second <- 0
Models$error_message <- ""

# Number of models
nOpt <- nrow(Models)
nOpt


# Option to sample specs
# specs <- 1:nrow(Models)
specs <- sample(1:nrow(Models), 10000)



# Run the Models in Parallel ----------------------------------------------
Model_Output <- foreach(i = specs, .combine = rbind, .packages = c("tidyverse", "fixest")) %dopar% {
  tryCatch(
    {
      # CHANGE: Create a local copy of 'data' for this iteration
      local_data <- data
      
      # Create the index for filtering
      index <- with(
        local_data, # CHANGE: Use local_data instead of data
        as.numeric(ins_prsn_covered_eoy_cnt_bins) > Models$Drop_Low[i] &
          as.numeric(ins_prsn_covered_eoy_cnt_bins) <= max(as.numeric(ins_prsn_covered_eoy_cnt_bins)) - Models$Drop_High[i] &
          (!Models$Drop_Mixed[i] | mixed_d != 1)
      )

      # If matching is false, drop missing = 1
      if (!Models$Matching[i]) {
        index <- index & (local_data$missing == 0) # CHANGE: Use local_data
      }

      # Count observations before IV filtering
      obs_before_iv <- sum(index)

      # Create the IV variable, potentially logged and winsorized
      iv_var <- Models$IV_Variable[i]
      iv_values <- local_data[[iv_var]] # CHANGE: Use local_data

      # Winsorize the IV variable if specified
      if (Models$Winsorize_IV[i] != "None") {
        if (Models$Winsorize_IV[i] == "99") {
          iv_values <- pmin(pmax(iv_values, quantile(iv_values, 0.005, na.rm = TRUE)), quantile(iv_values, 0.995, na.rm = TRUE))
        } else if (Models$Winsorize_IV[i] == "95") {
          iv_values <- pmin(pmax(iv_values, quantile(iv_values, 0.025, na.rm = TRUE)), quantile(iv_values, 0.975, na.rm = TRUE))
        }
      }

      # Log the IV variable if specified
      if (Models$Log_IV[i]) {
        iv_values <- log(iv_values + 1)
      }

      # Create the iv_did variable
      local_data$iv_did <- iv_values * local_data$post_covid # CHANGE: Use local_data

      # Update index to exclude NA values in IV
      index <- index & !is.na(local_data$iv_did) # CHANGE: Use local_data

      # Count observations after IV filtering
      obs_after_iv <- sum(index)

      # Check if more than 80% of observations were dropped due to IV
      if ((obs_before_iv - obs_after_iv) / obs_before_iv > 0.8) {
        # Return the row with 0s for outcomes
        result <- Models[i, ]
        result$treat <- 0
        result$fstat <- 0
        result$num_obs <- 0
        result$num_pos_sig_first <- 0
        result$num_neg_sig_first <- 0
        result$coef_second <- 0
        result$p_second <- 0
        result$error_message <- "IV filtering dropped more than 80% of observations."
        return(result)
      }

      # Winsorize the dependent variable if specified
      if (Models$Winsorize_DV[i] != "None") {
        if (Models$Winsorize_DV[i] == "99") {
          local_data$dwell_more_4h <- pmin(pmax(local_data$dwell_more_4h, quantile(local_data$dwell_more_4h, 0.005, na.rm = TRUE)), quantile(local_data$dwell_more_4h, 0.995, na.rm = TRUE))
        } else if (Models$Winsorize_DV[i] == "95") {
          local_data$dwell_more_4h <- pmin(pmax(local_data$dwell_more_4h, quantile(local_data$dwell_more_4h, 0.025, na.rm = TRUE)), quantile(local_data$dwell_more_4h, 0.975, na.rm = TRUE))
        }
      }

      # Log the dependent variable if specified
      if (Models$Log_DV[i]) {
        local_data$dwell_more_4h <- log(local_data$dwell_more_4h + 1) # CHANGE: Use local_data
      }

      # Check if more than 80% of observations were dropped due to DV
      obs_after_dv <- sum(!is.na(local_data$dwell_more_4h[index])) # CHANGE: Use local_data
      if ((obs_before_iv - obs_after_dv) / obs_before_iv > 0.8) {
        # Return the row with 0s for outcomes
        result <- Models[i, ]
        result$treat <- 0
        result$fstat <- 0
        result$num_obs <- 0
        result$num_pos_sig_first <- 0
        result$num_neg_sig_first <- 0
        result$coef_second <- 0
        result$p_second <- 0
        result$error_message <- "DV filtering dropped more than 80% of observations."
        return(result)
      }

      # Construct the formula
      fe_formula <- Models$Fixed_Effects[i]

      if (Models$Interact_Instrument[i] == "Yes") {
        iv_formula <- "did_fully_2020 ~ iv_did:ins_prsn_covered_eoy_cnt_bins"
      } else {
        iv_formula <- "did_fully_2020 ~ iv_did"
      }

      formula <- as.formula(paste(
        "dwell_more_4h", "~ 1 |", fe_formula, "|", iv_formula
      ))

      # Define the clustering variable(s)
      cluster_vars <- strsplit(as.character(Models$Cluster_By[i]), " \\+ ")[[1]]

      # Estimate the model using the index and the specified clustering
      model <- feols(formula, data = local_data, subset = index, cluster = cluster_vars) # CHANGE: Use local_data

      # Calculate percent change for treatment effect
      if (Models$Log_DV[i]) {
        Models$treat[i] <- (exp(coef(model)[1]) - 1)
      } else {
        mean_outcome <- mean(local_data$dwell_more_4h[index], na.rm = TRUE) # CHANGE: Use local_data
        Models$treat[i] <- (coef(model)[1] / mean_outcome)
      }

      # Calculate the number of observations
      Models$num_obs[i] <- model$nobs

      # Calculate the F-statistic
      Models$fstat[i] <- fitstat(model, "ivwald", simplify = TRUE)[1]

      # Extract first stage results
      first_stage <- summary(model, stage = 1)
      first_stage_coefs <- coef(first_stage)
      first_stage_pvalues <- pvalue(first_stage)

      # Count significant positive and negative coefficients
      Models$num_pos_sig_first[i] <- sum(first_stage_coefs > 0 & first_stage_pvalues < 0.05, na.rm = TRUE)
      Models$num_neg_sig_first[i] <- sum(first_stage_coefs < 0 & first_stage_pvalues < 0.05, na.rm = TRUE)

      # Extract second stage results
      second_stage <- summary(model, stage = 2)
      Models$coef_second[i] <- coef(second_stage)[1]
      Models$p_second[i] <- pvalue(second_stage)[1]

      # Ensure all columns are present in the returned row
      result <- Models[i, ]
      result$treat <- Models$treat[i]
      result$fstat <- Models$fstat[i]
      result$num_obs <- Models$num_obs[i]
      result$num_pos_sig_first <- Models$num_pos_sig_first[i]
      result$num_neg_sig_first <- Models$num_neg_sig_first[i]
      result$coef_second <- Models$coef_second[i]
      result$p_second <- Models$p_second[i]
      result$error_message <- ""

      return(result)
    },
    error = function(e) {
      # If an error occurs, capture the error message and return the row with default values
      result <- Models[i, ]
      result$treat <- 0
      result$fstat <- 0
      result$num_obs <- 0
      result$num_pos_sig_first <- 0
      result$num_neg_sig_first <- 0
      result$coef_second <- 0
      result$p_second <- 0
      result$error_message <- as.character(e)

      return(result)
    }
  )
}

# Close the parallel processing cluster
stopCluster(cl)

# After the parallel processing, check for any rows with errors
error_rows <- Models[Models$error_message != "", ]
if (nrow(error_rows) > 0) {
  cat("Errors occurred in", nrow(error_rows), "rows:\n")
  print(error_rows[, c("error_message", names(Models)[1:8])])
}

# Print top of the model output
head(Model_Output, 20)

# Save the results
save(Model_Output, file = "../Data/intermediate_data/spec_curve_results_iv.RData")



# Filter good IVs
Model_Output %>%
  mutate(Good_IV = (fstat > 10 & p_second < 0.1 & treat > 0 & treat < 0.5)) %>% 
  filter(Good_IV) %>% 
  View()






# nolint end

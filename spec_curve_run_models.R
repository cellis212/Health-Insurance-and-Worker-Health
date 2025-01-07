# nolint start: line_length_linter, trailing_whitespace_linter, indentation_linter, object_name_linter.

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
load("../Data/intermediate_data/data_balanced_pre_analysis.RData")

data <- data_balanced

# Define IV variables
IV_Variables <- c("linsurer_otstAMLR_LARGEGROUP")
IV_Option <- c("linsurer_otstAMLR_LARGEGROUP") 

# Options -----------------------------------------------------------------
Fixed_Effects <- c(
  "year_month_state + ein",
  "year_month_two_digit + ein",
  "year_month_state + year_month_two_digit + ein"
)  # Option for fixed effects
Interact_Instrument <- c("Bins", "Bins + 2_digit")  # Option to interact the IV with specified variables
Drop_Low <- c(0, 1, 2)  # Option for dropping bottom bins
Drop_High <- c(0, 1, 2)  # Option for dropping top bins
Drop_Mixed <- c(TRUE, FALSE)  # Option for dropping mixed_d == 1
Log_IV <- c(FALSE, TRUE)  # Option for logging the IV variable
Log_DV <- c(FALSE, TRUE)  # Option for logging the dependent variable
Cluster_By <- c("ein + naic_code", "ein")  # Option for clustering
Winsorize_IV <- c("None", "99")  # Option for winsorizing IV
Winsorize_DV <- c("None", "99")  # Option for winsorizing dependent variable
Matching <- c(TRUE)  # Option for matching
Treat_Var <- c("did_fully_2020")  # Option for treatment variable
Control_Size <- c(FALSE, TRUE)  # Option for controlling for size
Balance_Panel <- c(FALSE)  # Option for balancing the panel data
Dep_Var <- c("raw_visitor_counts")  # Option for dependent variable

# Create all combinations of options
Models <- expand.grid(
  Fixed_Effects = Fixed_Effects,
  Interact_Instrument = Interact_Instrument,
  Drop_Low = Drop_Low,
  Drop_High = Drop_High,
  Drop_Mixed = Drop_Mixed,
  IV_Option = IV_Option,
  Log_IV = Log_IV,
  Log_DV = Log_DV,
  Cluster_By = Cluster_By,
  Winsorize_IV = Winsorize_IV,
  Winsorize_DV = Winsorize_DV,
  Matching = Matching,
  Treat_Var = Treat_Var,
  Control_Size = Control_Size,
  Balance_Panel = Balance_Panel,
  Dep_Var = Dep_Var
)

Models$error_message <- ""

# Calculate pre-period means for dependent variables
data <- data %>%
  group_by(ein) %>%
  mutate(across(
    c("raw_visitor_counts", "dwell_more_4h"),
    ~ mean(.x[year < 2020], na.rm = TRUE),
    .names = "{.col}_pre"
  )) %>%
  ungroup()

# Get preferred specifications
pref_spec <- list(
  Fixed_Effects = "year_month_state + year_month_bins + ein",
  Interact_Instrument = "Bins + 2_digit",
  IV_Option = "Both",
  Drop_Low = "0",
  Drop_High = "0",
  Drop_Mixed = "TRUE",
  Log_IV = "TRUE",
  Log_DV = "FALSE",
  Winsorize_IV = "None",
  Winsorize_DV = "95",
  Matching = "TRUE",
  Treat_Var = "did_fully_2020",
  Control_Size = "FALSE",
  Cluster_By = "ein + naic_code",
  Balance_Panel = "TRUE",
  Dep_Var = "raw_visitor_counts"
)

# Get preferred specification indices
pref <- NULL
for (var in names(pref_spec)) {
  if (var %in% names(Models)) {
    matching_rows <- which(as.character(Models[[var]]) == as.character(pref_spec[[var]]))
    if (length(matching_rows) > 0) {
      if (is.null(pref)) {
        pref <- matching_rows
      } else {
        pref <- intersect(pref, matching_rows)
      }
    }
  }
}

# Option to sample specs
specs <- 1:nrow(Models)
# specs <- sample(1:nrow(Models), 10)
# specs <- 1191
# Run the Models in Parallel ----------------------------------------------
Model_Output <- foreach(
  i = specs,
  .combine = rbind,
  .packages = c("tidyverse", "fixest")
) %dopar% {
  tryCatch(
    {
      # Create a local copy of 'data' for this iteration
      local_data <- data

      # Balance the data if specified
      if (Models$Balance_Panel[i]) {
        local_data <- local_data %>%
          group_by(ein) %>%
          filter(n() == 36) %>%
          ungroup()
      }

      # Create the index for filtering
      index <- 1:nrow(local_data)

      # Drop mixed_d == 1 if specified
      if (Models$Drop_Mixed[i]) {
        index <- index[local_data$mixed_d != 1]
      }

      # Drop bottom bins if specified
      if (Models$Drop_Low[i] > 0) {
        index <- index[as.numeric(local_data$ins_prsn_covered_eoy_cnt_bins[index]) > Models$Drop_Low[i]]
      }

      # Drop top bins if specified
      if (Models$Drop_High[i] > 0) {
        index <- index[as.numeric(local_data$ins_prsn_covered_eoy_cnt_bins[index]) <= max(as.numeric(local_data$ins_prsn_covered_eoy_cnt_bins[index])) - Models$Drop_High[i]]
      }

      # Prepare IV variables
      iv_option <- Models$IV_Option[i]
      if (iv_option == "Both") {
        iv_vars <- IV_Variables
      } else {
        iv_vars <- iv_option
      }

      # Create the IV variable(s), potentially logged and winsorized
      for (iv_var in iv_vars) {
        iv_values <- local_data[[iv_var]]

        # Winsorize the IV variable if specified
        if (Models$Winsorize_IV[i] != "None") {
          if (Models$Winsorize_IV[i] == "99") {
            iv_values <- pmin(
              pmax(iv_values, quantile(iv_values, 0.005, na.rm = TRUE)),
              quantile(iv_values, 0.995, na.rm = TRUE)
            )
          } else if (Models$Winsorize_IV[i] == "95") {
            iv_values <- pmin(
              pmax(iv_values, quantile(iv_values, 0.025, na.rm = TRUE)),
              quantile(iv_values, 0.975, na.rm = TRUE)
            )
          }
        }

        # Log the IV variable if specified
        if (Models$Log_IV[i]) {
          iv_values <- log(iv_values + 1)
        }

        # Create the iv_did variable in the local copy
        local_data[[paste0(iv_var, "_did")]] <- iv_values * local_data$post_covid
      }

      # Update index to exclude NA values in any IV_did variables
      iv_did_vars <- paste0(iv_vars, "_did")

      # Initialize results list for this iteration
      results <- list()

      # Get the dependent variable for this iteration
      dv <- Models$Dep_Var[i]

      # Winsorize the dependent variable if specified
      if (Models$Winsorize_DV[i] != "None") {
        if (Models$Winsorize_DV[i] == "99") {
          local_data[[dv]] <- pmin(
            pmax(local_data[[dv]], quantile(local_data[[dv]], 0.005, na.rm = TRUE)),
            quantile(local_data[[dv]], 0.995, na.rm = TRUE)
          )
        } else if (Models$Winsorize_DV[i] == "95") {
          local_data[[dv]] <- pmin(
            pmax(local_data[[dv]], quantile(local_data[[dv]], 0.025, na.rm = TRUE)),
            quantile(local_data[[dv]], 0.975, na.rm = TRUE)
          )
        }
      }

      # Log the dependent variable if specified
      if (Models$Log_DV[i]) {
        local_data[[dv]] <- log(local_data[[dv]] + 1)
      }

      # Construct the formula
      fe_formula <- Models$Fixed_Effects[i]
      treat_var <- Models$Treat_Var[i]

      # Determine interaction term based on Interact_Instrument option
      interaction_option <- Models$Interact_Instrument[i]
      if (interaction_option == "Bins") {
        interaction_term <- "ins_prsn_covered_eoy_cnt_bins"
      } else if (interaction_option == "1_digit") {
        interaction_term <- "first_digit_business_code"
      } else if (interaction_option == "2_digit") {
        interaction_term <- "first_two_digits_business_code"
      } else if (interaction_option == "Bins + 2_digit") {
        interaction_term <- c("ins_prsn_covered_eoy_cnt_bins", "first_two_digits_business_code")
      } else {
        interaction_term <- NULL
      }

      # Build iv_formula
      if (!is.null(interaction_term)) {
        iv_terms <- c()
        for (iv_did_var in iv_did_vars) {
          if (length(interaction_term) == 1) {
            iv_terms <- c(iv_terms, paste0(iv_did_var, ":", interaction_term))
          } else {
            interactions <- paste(paste0(iv_did_var, ":", interaction_term), collapse = " + ")
            iv_terms <- c(iv_terms, interactions)
          }
        }
        iv_formula <- paste0(treat_var, " ~ ", paste(iv_terms, collapse = " + "))
      } else {
        iv_formula <- paste0(treat_var, " ~ ", paste(iv_did_vars, collapse = " + "))
      }

      # Build list of control variables
      controls_list <- c()

      # Add control for size if specified
      if (Models$Control_Size[i]) {
        controls_list <- c(controls_list, "year_month:ins_prsn_covered_eoy_cnt")
      }

      # Create controls string
      if (length(controls_list) == 0) {
        controls <- "1"
      } else {
        controls <- paste(controls_list, collapse = " + ")
      }

      # Define the full formula
      formula <- as.formula(paste(
        dv, "~", controls, "|", fe_formula, "|", iv_formula
      ))

      # Define the clustering variable(s)
      cluster_vars <- strsplit(as.character(Models$Cluster_By[i]), " \\+ ")[[1]]
      
      # Create filtered data
      filtered_data <- local_data[index, ]
      rm(local_data)

      # Further filter data for non-NA dependent variable values
      valid_dv <- !is.na(filtered_data[[dv]])
      filtered_data <- filtered_data[valid_dv, ]

      # Estimate the model using the filtered data and specified clustering
      model <- feols(formula, data = filtered_data, cluster = cluster_vars)

      # Calculate percent change for treatment effect and confidence interval
      if (Models$Log_DV[i]) {
        treat_effect <- exp(coef(model)[1]) - 1
        ci <- confint(model, level = 0.9)
        ub <- exp(ci[1, 2]) - 1
        lb <- exp(ci[1, 1]) - 1
      } else {
        pre_mean <- mean(filtered_data[[paste0(dv, "_pre")]], na.rm = TRUE)
        treat_effect <- coef(model)[1] / pre_mean
        ci <- confint(model, level = 0.9)
        ub <- ci[1, 2] / pre_mean
        lb <- ci[1, 1] / pre_mean
      }

      # Store the results
      results[["treat"]] <- treat_effect
      results[["ub_treat"]] <- ub
      results[["lb_treat"]] <- lb
      results[["i"]] <- i
      results$error_message <- ""

      return(results)
    },
    error = function(e) {
      # If an error occurs, capture the error message and return default values
      results <- list()
      results[["treat"]] <- NA
      results[["ub_treat"]] <- NA
      results[["lb_treat"]] <- NA
      results[["i"]] <- i
      results$error_message <- as.character(e)
      return(results)
    }
  )
}

# Close the parallel processing cluster
stopCluster(cl)

# Convert Model_Output to a dataframe and remove the row names
Model_Output <- as.data.frame(Model_Output)
rownames(Model_Output) <- NULL

# Drop the error column from Model_Output
Model_Output <- Model_Output[, !names(Model_Output) == "error_message"]

# Convert all columns to numeric
Model_Output <- Model_Output %>%
  mutate(across(everything(), as.numeric))

# Merge the results back into the Models dataframe
Models$i <- 1:nrow(Models)
Models <- left_join(Models, Model_Output, by = "i")

# Good Models
Models <- Models %>%
  mutate(
    good_model = if_else(
      treat > 0 &
        treat < 0.4 &
        ub_treat > 0 & 
        lb_treat > 0,
      TRUE, FALSE
    )
  )

# Save the results
save(Models, file = "../Data/intermediate_data/spec_curve_results.RData")

# nolint end

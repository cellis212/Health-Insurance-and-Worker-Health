# nolint start: line_length_linter, trailing_whitespace_linter.

# Pre-amble ---------------------------------------------------------------

# Clearing Memory
rm(list = ls())

# Loading packages
library(magrittr)
library(tidyverse)
library(cowplot)
library(vtable)
# Load models
load("../Data/intermediate_data/spec_curve_results.RData")


mod_good <- Models[Models$good_model == 1, ] %>% as.data.frame()


# Load paths
source("./Functions_and_Options.R")

# Order to print the options in
printOrder <- c(
  "Fixed_Effects",
  "Interact_Instrument",
  "Drop_Low",
  "Drop_High",
  "Drop_Mixed",
  "IV_Option",
  "Log_IV",
  "Log_DV",
  "Cluster_By",
  "Winsorize_IV",
  "Winsorize_DV",
  "Matching",
  "Treat_Var",
  "Control_Size"
)


# Drop options columns with only one value
columns_to_keep <- sapply(Models, function(x) length(unique(x)) > 1)
Models <- Models[, columns_to_keep]


# Update printOrder to remove dropped columns
printOrder <- printOrder[printOrder %in% names(Models)]

# Make sure all of the remaining printOrder variables are characters in the dataframe
Models[printOrder] <- lapply(Models[printOrder], as.character)

# Update preferred specification criteria
pref_spec <- list(
  Fixed_Effects = "year_month_state + ein",
  Interact_Instrument = "Bins",
  Drop_Low = "0",
  Drop_High = "0",
  Drop_Mixed = "FALSE",
  IV_Option = "Both",
  Log_IV = "TRUE",
  Log_DV = "FALSE",
  Cluster_By = "ein + naic_code",
  Winsorize_IV = "None",
  Winsorize_DV = "None",
  Matching = "TRUE",
  Treat_Var = "did_fully_2020",
  Control_Size = "FALSE"
)

# Names of dependent variables
treatvars <- c("raw_visitor_counts")

# Find the column locations for each treat variable
col_location <- which(names(Models) %in% paste0("treat_", treatvars))

curves <- data.frame(treatvars = treatvars, col_location = col_location)
curves$col_location <- as.numeric(curves$col_location)

# Direction of curves
# 1 for ascending, -1 for descending
curves$direct <- sapply(curves$col_location, function(col) {
  first_estimate <- Models[1, col]
  ifelse(first_estimate < 0, 1, -1)
})


# Keep only the criteria that are still in Models
pref_spec <- pref_spec[names(pref_spec) %in% names(Models)]

# Initializing
pref_coef <- c()
perSig <- c()
q25 <- c()
q75 <- c()

# Initialize a list to store results for each curve
curve_results <- list()

# Loop over different treat vars
for (curve_index in 1:nrow(curves)) {
  Models$estimate <- Models[, curves$col_location[curve_index]]
  Models$ub <- Models[, curves$col_location[curve_index] + 1]
  Models$lb <- Models[, curves$col_location[curve_index] + 2]

  # Getting Significance
  Models$sig <- as.factor(sign(Models$ub) == sign(Models$lb))

  # Calculate percentages for each choice
  choice_percentages <- list()
  
  for (choice in printOrder) {
    if (choice %in% names(Models)) {
      choice_percentages[[choice]] <- Models %>%
        group_by(!!sym(choice), sig) %>%
        summarise(count = n(), .groups = 'drop') %>%
        mutate(percentage = count / sum(count) * 100) %>%
        pivot_wider(names_from = sig, values_from = c(count, percentage)) %>%
        mutate(across(starts_with("percentage_"), ~ifelse(is.na(.), 0, .)))
    }
  }

  # Store results for this curve
  curve_results[[curves$treatvars[curve_index]]] <- choice_percentages

  # Ordering by estimate
  Models <- Models[order(Models$estimate * curves$direct[curve_index]), ]
  Models$Order <- 1:nrow(Models)

  # Get preferred specification using the updated criteria
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

  if (length(pref) == 0) {
    print("Preferred Spec not found!")
    pref_coef[curve_index] <- NA
    pref <- NA
  } else {
    pref_coef[curve_index] <- Models$estimate[pref[1]] # Use the first matching row if multiple exist
  }


  # Plotting ----------------------------------------------------------------

  # Update the color scale for the curve plot
  curve <- ggplot(data = Models) +
    geom_point(
      mapping = aes(x = Order, y = estimate, color = sig), size = 2
    ) +
    scale_color_manual(
      values = c("TRUE" = "black", "FALSE" = "gray70")
    ) +
    geom_linerange(
      mapping = aes(x = Order, ymin = lb, ymax = ub), colour = "blue", size = .05, alpha = .15
    ) +
    geom_vline(xintercept = pref, color = "red", linetype = "dashed") +
    geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
    theme(legend.position = "none") +
    labs(x = "Regression Number", y = "Estimate") + 
    coord_cartesian(ylim = c(-.5, 2))


  # Prepare data for specifications plot
  Models %>%
    select(Order, all_of(printOrder), sig) %>%
    pivot_longer(cols = all_of(printOrder), names_to = "key", values_to = "value") -> plotDat

  # Update the color scale for the specifications plot
  specs <- ggplot(
    data = plotDat,
    aes(
      x = plotDat$Order,
      y = plotDat$value,
      color = plotDat$sig
    )
  ) +
    scale_color_manual(
      values = c("TRUE" = "black", "FALSE" = "gray70")
    ) +
    geom_point(
      size = 1, # Adjust this for tick size
      shape = 124
    ) +
    facet_grid(rows = vars(key), scales = "free", space = "free") +
    theme(
      axis.line = element_line("black", size = .5),
      legend.position = "none",
      panel.spacing = unit(.75, "lines"),
      axis.text.y = element_text(size = 12, colour = "black"),
      axis.text.x = element_text(colour = "black"),
      strip.text.x = element_blank(),
      strip.text.y = element_text(
        face = "bold",
        size = 11
      ),
      strip.background.y = element_blank()
    ) +
    labs(x = "", y = "")

  #### MANUAL CHANGE REQUIRED ####
  # Fixing height for vars (lines in gp$heights that have null in the name are the ones to change)
  gp <- ggplotGrob(specs)

  # gp$heights[13] <- gp$heights[13] * 1.6
  # gp$heights[17] <- gp$heights[17] * 1.15

  # Combine the two plots
  plot_grid(curve,
    gp,
    labels = c(),
    align = "v",
    axis = "rbl",
    rel_heights = c(1.5, 6),
    ncol = 1
  )

  # Save the plot
  savename <- paste0(
    figure_path, "spec_curve_",
    curves$treatvars[curve_index], ".png"
  )

  ggsave(
    filename = savename,
    width = 12,
    height = 14,
    units = "in"
  )

  # Store results
  q25[curve_index] <- quantile(Models$estimate, .25, na.rm = TRUE)
  q75[curve_index] <- quantile(Models$estimate, .75, na.rm = TRUE)

  m <- sum(Models$ub < 0)
  n <- sum(Models$lb > 0)
  l <- max(m, n)
  perSig[curve_index] <- l / nrow(Models)
}

# Create a data frame with the results and add informative names
results_table <- data.frame(
  Variable = c("Raw Visitor Counts", "Raw Visit Counts", "Dwell Time > 4h"),
  PreferredCoef = pref_coef,
  PercentSignificant = perSig,
  Q25 = q25,
  Q75 = q75
)

# Function to format numbers
format_number <- function(x) {
  sprintf("%.3f", x)
}

# Create LaTeX table with notes using threeparttable
cat("\\begin{threeparttable}[htbp]
\\caption{Specification Curve Results}
\\label{tab:spec_curve_results}
\\begin{tabular}{lcccc}
\\hline
Variable & Preferred Coef. & Percent Significant & 5th Percentile & 95th Percentile \\\\
\\hline
", paste(sapply(1:nrow(results_table), function(i) {
  sprintf(
    "%s & %s & %.1f\\%% & %s & %s \\\\",
    results_table$Variable[i],
    format_number(results_table$PreferredCoef[i]),
    results_table$PercentSignificant[i] * 100,
    format_number(results_table$Q25[i]),
    format_number(results_table$Q75[i])
  )
}), collapse = "\n"), "
\\hline
\\end{tabular}
\\begin{tablenotes}
\\small
\\item \\linespread{1}\\selectfont\\textit{Notes:} This table presents the results of specification curve analyses for different dependent variables.
'Preferred Coef.' shows the coefficient from the preferred specification, which includes year-month-state and EIN fixed effects, interacted instrument, logged IV and DV, no winsorization of IV, 99th percentile winsorization of DV, matching, 'did_fully' treatment variable, and controlling for size.
'Percent Significant' indicates the percentage of specifications where the coefficient is statistically significant at the 10\\% level.
'5th Percentile' and '95th Percentile' show the distribution of coefficients across all specifications.
\\end{tablenotes}
\\end{threeparttable}
", file = "../Result/spec_curve_results.tex")



# Print summary for each curve
for (treat_var in names(curve_results)) {
  cat("\nSummary for", treat_var, ":\n")
  
  for (choice in names(curve_results[[treat_var]])) {
    cat("\n", choice, ":\n")
    print(curve_results[[treat_var]][[choice]])
  }
  
  cat("\n----------------------------\n")
}


# nolint end

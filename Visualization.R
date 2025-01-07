# nolint start: line_length_linter, trailing_whitespace_linter.


# Load required libraries
library(ggplot2)
library(data.table)

# Define file paths for project directories
project_dir <- "../Data"
interm_dir <- file.path(project_dir, "intermediate_data")
output_dir <- "../Result/reg results"

# Load the data for visualization
propensity_data <- readRDS(file.path(interm_dir, "propensity_data.RDS"))

# Create visualizations

# Normalized histogram of propensity scores
ggplot(propensity_data, aes(x = propensity_score, fill = factor(switcher))) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.7, position = "identity") +
  theme_minimal() +
  labs(title = "Normalized Distribution of Propensity Scores",
       x = "Propensity Score",
       y = "Density",
       fill = "Switcher") +
  scale_fill_manual(values = c("blue", "red"), labels = c("Non-switcher", "Switcher (Fully to Self)"))

# Histogram for insured person count
ggplot(propensity_data, aes(x = ins_prsn, fill = factor(switcher))) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.7, position = "identity") +
  theme_minimal() +
  labs(title = "Normalized Distribution of Insured Person Count",
       x = "Insured Person Count",
       y = "Density",
       fill = "Switcher") +
  scale_fill_manual(values = c("blue", "red"), labels = c("Non-switcher", "Switcher (Fully to Self)")) +
  scale_x_log10() # Use log scale for x-axis due to potential large range

# Overlapping histograms comparing self-insured vs. fully-insured by ins_prsn
ggplot(propensity_data, aes(x = ins_prsn, fill = factor(self_d))) +
  geom_histogram(aes(y = ..density..), bins = 30, alpha = 0.5, position = "identity") +
  theme_minimal() +
  labs(title = "Distribution of Insured Person Count: Self-Insured vs. Fully-Insured",
       x = "Insured Person Count",
       y = "Density",
       fill = "Insurance Type") +
  scale_fill_manual(values = c("blue", "red"), labels = c("Fully-Insured", "Self-Insured")) +
  scale_x_log10() +  # Use log scale for x-axis due to potential large range
  theme(legend.position = "bottom")

# Save the plot
ggsave(file.path(output_dir, "insured_person_count_histogram.png"), 
       width = 10, height = 6, dpi = 300)

# nolint end
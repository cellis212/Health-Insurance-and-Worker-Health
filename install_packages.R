# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Install required packages if they're not already installed
if (!require("tidyverse")) install.packages("tidyverse")
if (!require("tidycensus")) install.packages("tidycensus")
if (!require("haven")) install.packages("haven") 
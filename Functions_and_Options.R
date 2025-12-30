# Project: Collateral Asymmetric Info
# Functions and Options file


# Options -----------------------------------------------------------------
# Paths
if(getwd() == "C:/Users/celli/Dropbox/School/Papers/Health Insurance and Worker Health/Cam Code"){
  figure_path <- "C:/Users/celli/Dropbox/Apps/Overleaf/Self-Insurance IV Analysis/figures/"
  table_path <- "C:/Users/celli/Dropbox/Apps/Overleaf/Self-Insurance IV Analysis/tables/"
}


# Custom Functions --------------------------------------------------------
calculate_F_eff <- function(model, data, cluster = NULL) {
  # first_stage_model: fixest model object from the first-stage regression
  # data: Original data frame used in estimation
  # cluster: Optional clustering variable (as a formula, e.g., ~cluster_var)
  
  first_stage_model <- model$iv_first_stage

  # Check if instrument names are available
  instrument_names <- model$iv_inst_names
  if (is.null(instrument_names)) {
    stop("Instrument names not found in the model object.")
  }
  
  # Extract the observations used in the estimation
  obs_remove <- model$obs_selection$obsRemoved
  if (length(obs_remove) > 0) {
    data_used <- data[-obs_remove, ]
  } else {
    data_used <- data
  }
  
  # Recreate the model matrix for the instruments
  # Use the same formula as in the model and data_used to ensure consistency
  formula_instruments <- as.formula(paste("~", paste(instrument_names, collapse = "+")))
  instruments_matrix <- model.matrix(formula_instruments, data = data_used)
  
  # Extract estimated coefficients on instruments
  pi_hat <- coef(first_stage_model)[instrument_names]
  
  # Number of instruments
  k <- length(pi_hat)
  
  # Variance-covariance matrix of pi_hat (robust)
  if (is.null(cluster)) {
    Sigma_pi_pi_full <- vcov(first_stage_model, se = "hetero")
  } else {
    Sigma_pi_pi_full <- vcov(first_stage_model, se = "cluster", cluster = cluster)
  }
  Sigma_pi_pi <- Sigma_pi_pi_full[instrument_names, instrument_names, drop = FALSE]
  
  # Variance-covariance matrix of pi_hat (non-robust)
  Sigma_N_pi_pi_full <- vcov(first_stage_model, se = "iid")
  Sigma_N_pi_pi <- Sigma_N_pi_pi_full[instrument_names, instrument_names, drop = FALSE]
  
  # Sample variance-covariance matrix of instruments
  Q_ZZ <- var(instruments_matrix)
  
  # Compute traces required for adjustment factor
  tr_Sigma_QZZ <- sum(diag(Sigma_pi_pi %*% Q_ZZ))
  tr_Sigma_N_QZZ <- sum(diag(Sigma_N_pi_pi %*% Q_ZZ))
  
  # Adjustment factor
  adjustment <- tr_Sigma_N_QZZ / tr_Sigma_QZZ
  
  # Extract the usual first-stage F-statistic
  F_N <- first_stage_model$fstatistic[1]
  
  # Compute the effective F-statistic
  F_eff <- adjustment * F_N
  
  return(F_eff)
}















amortize = function(amount, rate, duration){
  # amount = the initial principal
  # rate = net interest rate (typically < 1), should be in effective APR
  # dur = number of periods
  
  amount * (rate * (1 + rate) ^ duration) / ((1 + rate) ^ duration - 1)
}

PV <- function(rate, nper, pmt, fv = 0) {
  stopifnot(is.numeric(rate), is.numeric(nper), is.numeric(pmt), is.numeric(fv), rate > 0, rate < 1, nper >= 1, pmt < 0)
  
  pvofregcash <- -pmt/rate * (1 - 1/(1 + rate)^nper)
  pvoffv <- fv/((1 + rate)^nper)
  
  return(round(pvofregcash - pvoffv, 2))
} 
# Variation of spread that spreads several columns
myspread <- function(df, key, value) {
  # quote key
  keyq <- rlang::enquo(key)
  # break value vector into quotes
  valueq <- rlang::enquo(value)
  s <- rlang::quos(!!valueq)
  df %>% gather(variable, value, !!!s) %>%
    unite(temp, !!keyq, variable) %>%
    spread(temp, value)
}

variable_cap = function(var, low_cap_percentile = 0, high_cap_percentile = 1) {
  # Caps extreme values of a variable (e.g., income)
  # var = variable to be capped
  # low_cap_percentile = percentile of lower bound cap, if any
  # high_cap_percentile = percentile of higher bound cap, if any
  
  var = var %>% 
    as.character() %>% 
    as.numeric()
  low_cap = quantile(var, low_cap_percentile, na.rm = T) %>%  # Converts lower bound percentile to a value of var
    as.numeric()
  high_cap = quantile(var, high_cap_percentile, na.rm = T) %>%  # Converts higher bound percentile to a value of var
    as.numeric()
  
  case_when(var < low_cap ~ low_cap,
            var > high_cap ~ high_cap,
            TRUE ~ var
  )
}




percentileFunc = function(inc, mat, cuts){
  # Function estimates the HH's income percentile.
  # inc = n x 1 vector of HH incomes
  # mat = n x m matrix of incomes that includes m income bins for each households (e.g., the distribution of incomes in a ZIP code in m buckets)
  # In mat, each n x m entry should be the number of HHs in that bin. From this, the function creates the density and cumulative of the distribution
  # cuts = cutpoints to place inc in the m income bins
  
  totalObs = rowSums(mat, na.rm = T) # Calculates total number of returns
  matDensity = mat / totalObs # Income distribution as % of total HHs in zip
  matDensity[is.na(mat)] = 0 # Replaces NA with zero for the cumulative
  
  ### Creates cumulative
  matCum = matDensity %>% 
    base::apply(1, cumsum) %>%  # explicitly stating base::apply bc acs also has an 'apply'
    t() %>% # Need to transpose the data
    data.frame()
  
  # Divides applicant income into the income bins, labels are structured [a, b)
  incLocAbove = cut(inc, breaks = cuts, right = F)
  binLength = length(table(incLocAbove))
  
  # New labels, which match column locations in the Census data
  levels(incLocAbove) = 1:ncol(mat)
  incLocAbove = incLocAbove.alt = as.numeric(as.character(incLocAbove)) # Converts factor to numeric.
  percLocAbove.alt = cbind(1:nrow(mat), incLocAbove.alt) # Gives coordinate for each applicant regarding the percentile
  densityAbove.alt = matDensity[percLocAbove.alt] # Gives the density (% of HHs) in the bin
  
  # If a bin has density = 0, this combines the bins
  ## Repeats this step until all empty categories are combined with other categories
  i = 1
  repeat{
    # print(i)
    incLocAbove.alt = ifelse(densityAbove.alt == 0 & incLocAbove.alt < binLength, (incLocAbove.alt + 1), incLocAbove.alt) # If the frequency in the bin is zero, then move the bound to the next bin. If there aren't enough observations in the top category, the IRS combines the category with the next lowest
    percLocAbove.alt = cbind(1:nrow(mat), incLocAbove.alt) # Gives coordinate for each applicant regarding the percentile of the Census data in app's ZIP. incCensus is a cumulative so this gives the upperbound percentile for the applicant
    densityAbove.alt = matDensity[percLocAbove.alt] # Gives the density (% of HHs) in the bin
    temp = table(densityAbove.alt == 0 & incLocAbove.alt < binLength) # Tells if there are still categories that need to be combined
    # print(temp)
    
    i = i + 1 # counts number of times iterated
    if(i == binLength | length(temp) == 1) break
  }
  
  
  # Now getting lower bound
  incLocBelow = incLocBelow.alt = incLocAbove - 1
  incLocBelow[incLocBelow == 0] = incLocBelow.alt[incLocBelow.alt == 0] = binLength + 1 # Can't have a location of zero so gives it a new location
  matDensity[ , (binLength + 1) ] = 0 # Adds column of zeros to match incLocBelow location
  matCum[ , (binLength + 1) ] = 0
  percLocBelow = cbind(1:nrow(mat), incLocBelow) # Gives coordinate for each applicant regarding the percentile of the Census data in app's ZIP. incCensus is a cumulative so this gives the lowerbound percentile for the applicant
  densityBelow.alt = matDensity[percLocBelow] # Gives the density (% of HHs) in the bin
  percentBelow.alt = matCum[percLocBelow]
  
  j = 1
  repeat{
    # print(j)
    incLocBelow.alt = ifelse( (densityBelow.alt == 0 | percentBelow.alt == 1) & incLocBelow.alt != (binLength + 1), 
                              (incLocBelow.alt - 1), 
                              incLocBelow.alt
    ) # If the frequency in the bin is zero, then move the bound to the next bin.
    incLocBelow.alt[incLocBelow.alt == 0] = binLength + 1 # Can't have a location of zero so gives it a new location
    percLocBelow.alt = cbind(1:nrow(mat), incLocBelow.alt) # Gives coordinate for each applicant regarding the percentile
    percentBelow.alt = matCum[percLocBelow.alt]
    densityBelow.alt = matDensity[percLocBelow.alt] # Gives the density (% of HHs) in the bin
    temp = table(densityBelow.alt == 0 & incLocBelow.alt != (binLength + 1)) # Tells if there are still categories that need to be combined
    # print(temp)
    
    j = j + 1 # counts number of times iterated
    if(j == binLength | length(temp) == 1) break
  }
  
  percentAbove.alt = matCum[percLocAbove.alt] # Gives the percentile above
  percentBelow.alt = matCum[percLocBelow.alt] # Gives the percentile below
  
  # (Linearly) interpolating between endpoints
  lowerCut = cuts[ (incLocBelow.alt + 1) ]
  lowerCut[incLocBelow.alt > binLength] = cuts[1]
  upperCut = cuts[ (incLocAbove.alt + 1) ]
  
  weightBtwn = (inc - lowerCut) / (upperCut - lowerCut) # Percent that income is between the lower and upper endpoints
  percentile0 = (1 - weightBtwn) * percentBelow.alt + weightBtwn * percentAbove.alt # Weights the two endpoints
  
  ## Dealing with lower and upper truncation. Current approach uses average of lower and upper bound
  percentile = ifelse(percentBelow.alt == 0 | percentAbove.alt == 1,
                      0.5 * percentBelow.alt + 0.5 * percentAbove.alt,
                      percentile0
  )
  
  varZip = mat %>% 
    as.matrix() %>% 
    rowVars() # Gets variance of income percentiles for each zip
  
  percentile[varZip == 0] = NA # Removes cases with no variation -- where the IRS does not report income for the ZIP (bc the pop is too low), or they only report one category
  percentile[totalObs == 0] = NA
  
  ## The commented tibble is useful for checking values
  # tibble(percentile, inc, incLocBelow.alt, incLocBelow, incLocAbove, incLocAbove.alt, lowerCut, upperCut, percentBelow.alt, percentAbove.alt)
  percentile
}


ptab = function(..., margin = NULL){
  # Concise command to create percent tables
  prop.table(table(...), margin)
}

sumStats = function(x, y){
  # Summary stats table to be passed to dplyr functions
  # x is a data frame
  # y is a column in that data frame
  y = enquo(y)
  
  summarise(x,
            Mean = mean(!! y, na.rm = T),
            SD = sd(!! y, na.rm = T),
            # p1 = quantile(!! y, 0.01, na.rm = T),
            p10 = quantile(!! y, 0.10, na.rm = T),
            # p25 = quantile(!! y, 0.25, na.rm = T),
            p50 = quantile(!! y, 0.50, na.rm = T),
            # p75 = quantile(!! y, 0.75, na.rm = T),
            p90 = quantile(!! y, 0.9, na.rm = T),
            # p99 = quantile(!! y, 0.99, na.rm = T),
            Obs = table(is.na(!! y))[1] 
  ) 
}

sumStats_NA = function(x, y){
  # Summary stats table to be passed to dplyr functions, includes number of NAs
  y = enquo(y)
  
  summarise(x,
            Mean = mean(!! y, na.rm = T),
            SD = sd(!! y, na.rm = T),
            p1 = quantile(!! y, 0.01, na.rm = T),
            p25 = quantile(!! y, 0.25, na.rm = T),
            p50 = quantile(!! y, 0.50, na.rm = T),
            p75 = quantile(!! y, 0.75, na.rm = T),
            p99 = quantile(!! y, 0.99, na.rm = T),
            Obs = n(),
            'NA' = n() - table(is.na(!! y))[1]           
  ) 
}


getmode <- function(v) {
  uniqv <- na.omit(unique(v))
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

# Finite difference for pdfs
finite.differences <- function(x, y) {
  if (length(x) != length(y)) {
    stop('x and y vectors must have equal length')
  }
  
  n <- length(x)
  
  # Initialize a vector of length n to enter the derivative approximations
  fdx <- vector(length = n)
  
  # Iterate through the values using the forward differencing method
  for (i in 2:n) {
    fdx[i-1] <- (y[i-1] - y[i]) / (x[i-1] - x[i])
  }
  
  # For the last value, since we are unable to perform the forward differencing method 
  # as only the first n values are known, we use the backward differencing approach
  # instead. Note this will essentially give the same value as the last iteration 
  # in the forward differencing method, but it is used as an approximation as we 
  # don't have any more information
  fdx[n] <- (y[n] - y[n - 1]) / (x[n] - x[n - 1])
  
  return(fdx)
}


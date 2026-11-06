sensitivity_baseline <- function() {
  list(
    outcome = "cigsale", unit_col = "state_id", time_col = "year",
    treated = 3, treatment_time = 1989, controls = c(1, 2, 4, 5),
    predictors = "retprice", pre_periods = 1980:1988,
    special_predictors = list(list("cigsale", c(1980, 1988), "mean"))
  )
}

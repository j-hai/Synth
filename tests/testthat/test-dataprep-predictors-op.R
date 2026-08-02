test_that("predictors.op is applied to control units as well as the treated unit", {
  # dataprep() aggregated the treated unit with predictors.op but the controls
  # with a hard-coded mean, so any operator other than "mean" produced an
  # internally inconsistent predictor-balance matrix.
  data(basque, envir = environment())

  controls <- c(2:16, 18)
  prior <- 1964:1969

  dp <- suppressMessages(dataprep(
    foo = basque,
    predictors = "invest",
    predictors.op = "median",
    dependent = "gdpcap",
    unit.variable = "regionno",
    time.variable = "year",
    treatment.identifier = 17,
    controls.identifier = controls,
    time.predictors.prior = prior,
    time.optimize.ssr = 1960:1969,
    time.plot = 1955:1997))

  hand_median <- vapply(controls, function(u) {
    median(basque$invest[basque$regionno == u & basque$year %in% prior], na.rm = TRUE)
  }, numeric(1))

  # the treated unit already honoured the operator
  expect_equal(
    unname(dp$X1[1, 1]),
    median(basque$invest[basque$regionno == 17 & basque$year %in% prior], na.rm = TRUE)
  )

  # and now so do the controls
  expect_equal(unname(dp$X0[1, ]), unname(hand_median))
})

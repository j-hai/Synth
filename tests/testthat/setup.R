## Shared fixtures across the test suite. Loaded automatically by testthat.

data(synth.data, package = "Synth", envir = environment())

# A canonical dataprep object — the toy-panel example from ?synth and
# ?dataprep. It differs from s1_toy_panel in dev/01_capture_baseline.R in
# one special predictor: the frozen 1.1-9 baseline uses Y in 1991 (the
# first post-treatment year); here and in the docs it is Y in 1990.
make_dataprep <- function() {
  dataprep(
    foo = synth.data,
    predictors = c("X1", "X2", "X3"),
    predictors.op = "mean",
    dependent = "Y",
    unit.variable = "unit.num",
    time.variable = "year",
    special.predictors = list(
      list("Y", 1990, "mean"),
      list("Y", 1985, "mean"),
      list("Y", 1980, "mean")
    ),
    treatment.identifier = 7,
    controls.identifier = c(29, 2, 13, 17, 32, 38),
    time.predictors.prior = c(1984:1989),
    time.optimize.ssr = c(1984:1990),
    unit.names.variable = "name",
    time.plot = 1984:1996
  )
}

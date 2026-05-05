test_that("synth_data() with auto-controls reproduces a hand-built dataprep on basque", {
  data(basque)
  manual <- dataprep(
    foo                  = basque,
    predictors           = c("school.illit", "school.prim", "invest"),
    predictors.op        = "mean",
    dependent            = "gdpcap",
    unit.variable        = "regionno",
    time.variable        = "year",
    special.predictors   = list(list("gdpcap", 1960:1969, "mean")),
    treatment.identifier = 17,
    controls.identifier  = c(2:16, 18),
    time.predictors.prior = 1960:1969,
    time.optimize.ssr     = 1960:1969,
    unit.names.variable   = "regionname",
    time.plot             = 1955:1997
  )

  auto <- synth_data(
    panel              = basque,
    outcome            = "gdpcap",
    unit_col           = "regionno",
    time_col           = "year",
    treated            = 17,
    controls           = c(2:16, 18),
    treatment_time     = 1970,
    predictors         = c("school.illit", "school.prim", "invest"),
    special_predictors = list(list("gdpcap", 1960:1969, "mean")),
    pre_periods        = 1960:1969,
    plot_periods       = 1955:1997,
    unit_names_col     = "regionname"
  )

  # Key matrices should be identical
  expect_equal(auto$X1, manual$X1)
  expect_equal(auto$X0, manual$X0)
  expect_equal(auto$Z1, manual$Z1)
  expect_equal(auto$Z0, manual$Z0)
  expect_equal(auto$Y1plot, manual$Y1plot)
  expect_equal(auto$Y0plot, manual$Y0plot)
})

test_that("synth_data() default controls = all other units", {
  data(basque)
  auto <- synth_data(
    panel          = basque,
    outcome        = "gdpcap",
    unit_col       = "regionno",
    time_col       = "year",
    treated        = 17,
    treatment_time = 1970,
    pre_periods    = 1960:1969,
    plot_periods   = 1955:1997,
    unit_names_col = "regionname",
    special_predictors = list(list("gdpcap", 1960:1969, "mean"))
  )
  # All region ids except 17 → 17 controls (basque has 1..18)
  expect_equal(ncol(auto$X0), length(unique(basque$regionno)) - 1)
})

test_that("synth_data() resolves treated by name when unit_names_col is supplied", {
  data(basque)
  auto <- synth_data(
    panel          = basque,
    outcome        = "gdpcap",
    unit_col       = "regionno",
    time_col       = "year",
    treated        = "Basque Country (Pais Vasco)",
    treatment_time = 1970,
    pre_periods    = 1960:1969,
    plot_periods   = 1955:1997,
    unit_names_col = "regionname",
    special_predictors = list(list("gdpcap", 1960:1969, "mean"))
  )
  # X1 should match what the numeric-id resolution gives
  ref <- synth_data(
    panel          = basque,
    outcome        = "gdpcap",
    unit_col       = "regionno",
    time_col       = "year",
    treated        = 17,
    treatment_time = 1970,
    pre_periods    = 1960:1969,
    plot_periods   = 1955:1997,
    unit_names_col = "regionname",
    special_predictors = list(list("gdpcap", 1960:1969, "mean"))
  )
  expect_equal(auto$X1, ref$X1)
})

test_that("synth_data() works with default special_predictors = list()", {
  data(basque)
  # Repro for the "subscript out of bounds" reviewer report: omit
  # special_predictors entirely. dataprep() needs NULL for the empty
  # case; synth_data() must translate.
  expect_error(
    auto <- synth_data(
      panel          = basque,
      outcome        = "gdpcap",
      unit_col       = "regionno",
      time_col       = "year",
      treated        = 17,
      controls       = c(2:16, 18),
      treatment_time = 1970,
      predictors     = c("school.illit", "school.prim", "invest"),
      pre_periods    = 1960:1969,
      plot_periods   = 1955:1997,
      unit_names_col = "regionname"
    ),
    NA
  )
  expect_equal(ncol(auto$X1), 1)
})

test_that("synth_data() works without unit_names_col (numeric ids only)", {
  data(basque)
  # Repro for the "missing value where TRUE/FALSE needed" reviewer
  # report: NULL passed straight through fails dataprep's predicate.
  expect_error(
    auto <- synth_data(
      panel          = basque,
      outcome        = "gdpcap",
      unit_col       = "regionno",
      time_col       = "year",
      treated        = 17,
      controls       = c(2:16, 18),
      treatment_time = 1970,
      predictors     = c("school.illit", "school.prim", "invest"),
      pre_periods    = 1960:1969,
      plot_periods   = 1955:1997
    ),
    NA
  )
  expect_equal(ncol(auto$X1), 1)
})

test_that("synth_data() rejects malformed inputs", {
  data(basque)
  expect_error(synth_data(panel = matrix(1)), "must be a data.frame")
  expect_error(synth_data(panel = basque, outcome = "gdpcap",
                          treated = 17, treatment_time = 1970),
               "unit_col and time_col are required")
  expect_error(synth_data(panel = basque, outcome = "nonsense_col",
                          treated = 17, unit_col = "regionno",
                          time_col = "year", treatment_time = 1970),
               "not found in panel")
  expect_error(synth_data(panel = basque, outcome = "gdpcap",
                          treated = "Basque Country (Pais Vasco)",
                          unit_col = "regionno", time_col = "year",
                          treatment_time = 1970),
               "unit_names_col is NULL")
  expect_error(synth_data(panel = basque, outcome = "gdpcap",
                          treated = 17, unit_col = "regionno",
                          time_col = "year",
                          treatment_time = "1970"),
               "single finite numeric")
})

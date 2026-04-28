test_that("dataprep() builds the expected matrix shapes", {
  d <- make_dataprep()

  expect_type(d, "list")
  expect_named(d, c("X0", "X1", "Z0", "Z1",
                    "Y0plot", "Y1plot",
                    "names.and.numbers", "tag"))

  # X1: predictors x 1 treated unit. We have 3 regular + 3 special = 6 rows.
  expect_equal(dim(d$X1), c(6L, 1L))
  expect_equal(colnames(d$X1), "7")

  # X0: predictors x n_controls
  expect_equal(dim(d$X0), c(6L, 6L))
  expect_setequal(as.integer(colnames(d$X0)),
                  c(29L, 2L, 13L, 17L, 32L, 38L))

  # Z1: time.optimize.ssr x 1 treated
  expect_equal(dim(d$Z1), c(7L, 1L))

  # Z0: time.optimize.ssr x n_controls
  expect_equal(dim(d$Z0), c(7L, 6L))

  # No NAs anywhere in the inputs
  expect_false(anyNA(d$X1))
  expect_false(anyNA(d$X0))
  expect_false(anyNA(d$Z1))
  expect_false(anyNA(d$Z0))
})

test_that("dataprep() rejects malformed inputs", {
  expect_error(
    dataprep(foo = "not a data frame"),
    "data.frame"
  )

  expect_error(
    dataprep(foo = synth.data,
             predictors = c("X1", "X2"),
             dependent = "Y",
             unit.variable = "unit.num",
             time.variable = "year",
             treatment.identifier = 7,
             controls.identifier = c(29),  # only one control
             time.predictors.prior = c(1984:1989),
             time.optimize.ssr = c(1984:1990),
             time.plot = 1984:1996),
    "at least two control"
  )
})

test_that("dataprep() handles single-period special predictors", {
  d <- dataprep(
    foo = synth.data,
    predictors = c("X1"),
    predictors.op = "mean",
    dependent = "Y",
    unit.variable = "unit.num",
    time.variable = "year",
    special.predictors = list(
      list("Y", 1985, "mean")
    ),
    treatment.identifier = 7,
    controls.identifier = c(29, 2, 13, 17),
    time.predictors.prior = c(1984:1989),
    time.optimize.ssr = c(1984:1990),
    time.plot = 1984:1996
  )
  expect_equal(nrow(d$X1), 2L)  # 1 regular + 1 special
})

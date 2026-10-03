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

# dataprep() sorts foo by unit and time, so labels have to follow that order
# whatever order the identifiers and periods are supplied in.
toy_dataprep <- function(controls = c(29, 2, 13, 17, 32, 38),
                         predictors = c("X1", "X2", "X3"),
                         special = list(list("Y", 1990, "mean"),
                                        list("Y", 1985, "mean")),
                         treated = 7, prior = 1984:1989,
                         ssr = 1984:1990, plot = 1984:1996) {
  dataprep(
    foo = synth.data,
    predictors = predictors,
    predictors.op = "mean",
    dependent = "Y",
    unit.variable = "unit.num",
    time.variable = "year",
    special.predictors = special,
    treatment.identifier = treated,
    controls.identifier = controls,
    time.predictors.prior = prior,
    time.optimize.ssr = ssr,
    unit.names.variable = "name",
    time.plot = plot
  )
}

expect_labels_match_data <- function(d) {
  y <- function(unit, years) {
    sd <- synth.data[synth.data$unit.num == unit, ]
    sd$Y[match(years, sd$year)]
  }
  for (m in c("Z0", "Y0plot", "Z1", "Y1plot")) {
    mat <- d[[m]]
    years <- as.numeric(rownames(mat))
    for (u in colnames(mat)) {
      expect_equal(unname(mat[, u]), y(as.numeric(u), years),
                   info = paste(m, "column", u))
    }
  }
  # special.Y.1985 is the 1985 outcome of the unit the column is named for
  for (u in colnames(d$X0)) {
    expect_equal(unname(d$X0["special.Y.1985", u]), y(as.numeric(u), 1985),
                 info = paste("X0 column", u))
  }
  expect_identical(colnames(d$Z0), colnames(d$X0))
  expect_identical(colnames(d$Y0plot), colnames(d$X0))
}

test_that("control labels follow the data when controls.identifier is unsorted", {
  specs <- list(
    several_predictors = list(predictors = c("X1", "X2", "X3")),
    single_predictor   = list(predictors = "X2"),
    special_only       = list(predictors = NULL)
  )
  for (nm in names(specs)) {
    d <- toy_dataprep(predictors = specs[[nm]]$predictors)
    expect_identical(colnames(d$X0), c("2", "13", "17", "29", "32", "38"),
                     info = nm)
    expect_labels_match_data(d)
    expect_equal(d, toy_dataprep(controls = c(2, 13, 17, 29, 32, 38),
                                 predictors = specs[[nm]]$predictors),
                 info = nm)
  }
})

test_that("unit names follow unit numbers when controls.identifier is unsorted", {
  ids <- unique(synth.data[, c("unit.num", "name")])
  true_name <- function(u) ids$name[match(u, ids$unit.num)]

  d <- toy_dataprep()
  nn <- d$names.and.numbers
  expect_equal(as.character(nn$unit.names), true_name(nn$unit.numbers))

  tab <- synth.tab(dataprep.res = d,
                   synth.res = synth(d, verbose = FALSE))$tab.w
  expect_equal(as.character(tab$unit.numbers), rownames(tab))
  expect_equal(as.character(tab$unit.names), true_name(tab$unit.numbers))

  # same result when the controls are given by name, in any order
  by_name <- toy_dataprep(controls = rev(true_name(c(29, 2, 13, 17, 32, 38))))
  expect_equal(by_name, d)
})

test_that("synth.tab() matches names to weights by unit number", {
  d <- toy_dataprep()
  fit <- synth(d, verbose = FALSE)
  shuffled <- d
  shuffled$names.and.numbers <- d$names.and.numbers[c(4, 1, 7, 2, 6, 3, 5), ]
  expect_equal(synth.tab(dataprep.res = shuffled, synth.res = fit)$tab.w,
               synth.tab(dataprep.res = d, synth.res = fit)$tab.w,
               ignore_attr = "row.names")
  expect_equal(rownames(synth.tab(dataprep.res = shuffled,
                                  synth.res = fit)$tab.w),
               rownames(fit$solution.w))
})

test_that("period labels follow the data when periods are unsorted", {
  d <- toy_dataprep(prior = c(1989, 1984:1988), ssr = c(1990, 1984:1989),
                    plot = c(1991:1996, 1984:1990))
  expect_identical(rownames(d$Z1), as.character(1984:1990))
  expect_identical(rownames(d$Y1plot), as.character(1984:1996))
  expect_labels_match_data(d)
  expect_equal(d, toy_dataprep())

  # the missing-data notice names the period that is actually missing
  holed <- synth.data
  holed$X2[holed$unit.num == 13 & holed$year == 1984] <- NA
  expect_output(
    dataprep(foo = holed, predictors = c("X2", "X3"), dependent = "Y",
             unit.variable = "unit.num", time.variable = "year",
             treatment.identifier = 7, controls.identifier = c(29, 2, 13, 17),
             time.predictors.prior = c(1989, 1984:1988),
             time.optimize.ssr = 1984:1990, time.plot = 1984:1996),
    "control unit: 13 ; predictor: X2 ; for period: 1984"
  )
})

sensitivity_baseline <- function() {
  list(outcome = "cigsale", unit_col = "state_id", time_col = "year",
       treated = 3, treatment_time = 1989, controls = c(1, 2, 4, 5),
       predictors = "retprice", pre_periods = 1980:1988,
       special_predictors = list(list("cigsale", c(1980, 1988), "mean")))
}

test_that("baseline matches synth with aligned weights and common ATT", {
  data(smoking)
  baseline <- sensitivity_baseline()
  dp <- do.call(synth_data, c(list(panel = smoking), baseline))
  fit <- synth(dp)
  res <- synth_sensitivity(smoking, baseline, list(baseline = list()), 1989:2000)
  expect_s3_class(res, "synth_sensitivity")
  expect_equal(res$weights$weight, as.numeric(fit$solution.w), tolerance = 1e-9)
  cf <- as.numeric(dp$Y0plot %*% fit$solution.w)
  expect_equal(res$paths$synthetic, cf, tolerance = 1e-9)
  expect_equal(res$summary$att, mean((dp$Y1plot - cf)[rownames(dp$Y1plot) %in% 1989:2000]))
  expect_equal(res$summary$fit_rmse, sqrt(as.numeric(fit$loss.v)))
  expect_equal(as.data.frame(res), res$summary)
  expect_equal(summary(res)$attempted, 1)
})

test_that("donor reordering and invalid designs do not affect other fits", {
  data(smoking)
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(
    reversed = list(controls = c(5, 4, 2, 1)),
    invalid = list(predictors = "absent"),
    short = list(pre_periods = 1984:1988)
  ), 1989:2000)
  expect_equal(nrow(res$summary), 4)
  expect_equal(res$summary$att[1], res$summary$att[2], tolerance = 1e-9)
  expect_equal(res$failures$spec_id, "invalid")
  expect_true(is.finite(res$summary$att[4]))
  expect_equal(res$registry$reversed$controls, c(5, 4, 2, 1))
})

test_that("identity, contamination and all predictor windows are checked", {
  data(smoking)
  invalid <- list(
    outcome = list(outcome = "retprice"),
    treatment = list(treatment_time = 1990),
    lag = list(special_predictors = list(list("cigsale", 1989, "mean"))),
    average = list(pre_periods = 1980:1989),
    plotting = list(plot_periods = 1980:1999),
    empty = list(pre_periods = numeric()),
    absent = list(pre_periods = 1900:1910),
    repeated = list(controls = c(1, 1, 2))
  )
  res <- synth_sensitivity(smoking, sensitivity_baseline(), invalid, 1989:2000)
  expect_equal(nrow(res$failures), length(invalid))
  expect_equal(res$summary$status[1], "ok")
  bad <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000,
                           excluded_donors = 1)
  expect_equal(bad$summary$status, "failed")
  expect_equal(summary(bad)$failed, 1)
  expect_true(is.na(summary(bad)$positive_share))
})

test_that("missing post outcomes cannot silently shorten the ATT period", {
  data(smoking)
  smoking$cigsale[smoking$state_id == 1 & smoking$year == 1995] <- NA
  res <- synth_sensitivity(smoking, sensitivity_baseline(),
                           list(complete = list(controls = c(2, 4, 5))), 1989:2000)
  expect_equal(res$summary$status, c("failed", "ok"))
  expect_equal(res$metadata$att_periods, 1989:2000)
})

test_that("legacy dataprep configurations retain special windows", {
  data(smoking)
  baseline <- list(dependent = "cigsale", unit.variable = "state_id",
                   time.variable = "year", treatment.identifier = 3,
                   controls.identifier = c(1, 2, 4, 5), predictors = "retprice",
                   predictors.op = "mean", time.predictors.prior = 1980:1988,
                   time.optimize.ssr = 1980:1988,
                   special.predictors = list(list("cigsale", c(1980, 1988), "mean")))
  res <- synth_sensitivity(smoking, baseline,
                           list(short = list(time.optimize.ssr = 1984:1988)),
                           1989:2000, interface = "dataprep", treatment_time = 1989)
  ref <- do.call(dataprep, c(list(foo = smoking, time.plot = 1970:2000), baseline))
  fit <- synth(ref)
  expect_equal(res$weights$weight[res$weights$spec_id == "baseline"], as.numeric(fit$solution.w))
  expect_equal(res$registry$short$time.predictors.prior, 1980:1988)
  expect_equal(res$summary$status, c("ok", "ok"))
})

test_that("study and registry errors are distinguished from failed designs", {
  data(smoking)
  b <- sensitivity_baseline()
  for (periods in list(numeric(), c(1988, 1989), c(1989, 1989), 2001))
    expect_error(synth_sensitivity(smoking, b, list(), periods), "att_periods")
  expect_error(synth_sensitivity(smoking, b, list(a = list(), a = list()), 1989:2000), "names")
  expect_error(synth_sensitivity(smoking, b, list(), 1989:2000,
                                 synth_args = list(X0 = matrix(1))), "synth_args")
})

test_that("post-treatment outcomes never affect fitted weights", {
  data(smoking)
  ref <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  smoking$cigsale[smoking$year >= 1989] <- smoking$cigsale[smoking$year >= 1989] + 1000
  changed <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  expect_equal(ref$weights, changed$weights)
})

test_that("both plot types handle all failures and mixed results", {
  data(smoking)
  file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file)
  on.exit({grDevices::dev.off(); unlink(file)}, add = TRUE)
  for (excluded in list(numeric(), 1)) {
    res <- synth_sensitivity(smoking, sensitivity_baseline(),
                             list(bad = list(predictors = "absent")), 1989:2000,
                             excluded_donors = excluded)
    expect_invisible(plot(res))
    expect_invisible(plot(res, type = "paths"))
    expect_output(print(res), "attempted")
  }
})

test_that("solver warnings retain finite estimates and diagnostics", {
  data(smoking)
  original <- synth
  testthat::local_mocked_bindings(synth = function(...) {
    warning("solver did not converge")
    original(...)
  })
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  expect_equal(res$summary$status, "warning")
  expect_true(is.finite(res$summary$att))
  expect_match(res$warnings$message, "did not converge")
  expect_equal(summary(res)$with_warnings, 1)
})

test_that("ipop nonconvergence is exposed without changing its weights", {
  H <- diag(3)
  cvec <- c(-1, -2, -3)
  pars <- list(maxiter = 1)
  expect_warning(w <- Synth:::.solve_w_ipop(H, cvec, pars), "did not converge")
  expect_true(all(is.finite(w)))
})

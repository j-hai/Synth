sensitivity_baseline <- function() {
  list(
    outcome = "cigsale", unit_col = "state_id", time_col = "year",
    treated = 3, treatment_time = 1989, controls = c(1, 2, 4, 5),
    predictors = "retprice", pre_periods = 1980:1988,
    special_predictors = list(list("cigsale", c(1980, 1988), "mean"))
  )
}

test_that("baseline matches synth with aligned weights and common ATT", {
  data(smoking)
  baseline <- sensitivity_baseline()
  dp <- do.call(synth_data, c(list(panel = smoking), baseline))
  fit <- synth(dp)
  res <- synth_sensitivity(
    smoking, baseline, list(baseline = list()), 1989:2000
  )
  expect_s3_class(res, "synth_sensitivity")
  expect_equal(res$weights$weight, as.numeric(fit$solution.w), tolerance = 1e-9)
  cf <- as.numeric(dp$Y0plot %*% fit$solution.w)
  expect_equal(res$paths$synthetic, cf, tolerance = 1e-9)
  post <- rownames(dp$Y1plot) %in% 1989:2000
  expect_equal(res$summary$att, mean((dp$Y1plot - cf)[post]))
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
    excluded_donors = 1
  )
  expect_equal(bad$summary$status, "failed")
  expect_equal(summary(bad)$failed, 1)
  expect_true(is.na(summary(bad)$positive_share))
})

test_that("missing post outcomes cannot silently shorten the ATT period", {
  data(smoking)
  smoking$cigsale[smoking$state_id == 1 & smoking$year == 1995] <- NA
  res <- synth_sensitivity(
    smoking, sensitivity_baseline(),
    list(complete = list(controls = c(2, 4, 5))), 1989:2000
  )
  expect_equal(res$summary$status, c("failed", "ok"))
  expect_equal(res$metadata$att_periods, 1989:2000)
})

test_that("legacy dataprep configurations retain special windows", {
  data(smoking)
  baseline <- list(
    dependent = "cigsale", unit.variable = "state_id",
    time.variable = "year", treatment.identifier = 3,
    controls.identifier = c(1, 2, 4, 5), predictors = "retprice",
    predictors.op = "mean", time.predictors.prior = 1980:1988,
    time.optimize.ssr = 1980:1988,
    special.predictors = list(list("cigsale", c(1980, 1988), "mean"))
  )
  res <- synth_sensitivity(smoking, baseline,
    list(short = list(time.optimize.ssr = 1984:1988)),
    1989:2000,
    interface = "dataprep", treatment_time = 1989
  )
  ref <- do.call(
    dataprep, c(list(foo = smoking, time.plot = 1970:2000), baseline)
  )
  fit <- synth(ref)
  expect_equal(
    res$weights$weight[res$weights$spec_id == "baseline"],
    as.numeric(fit$solution.w)
  )
  expect_equal(res$registry$short$time.predictors.prior, 1980:1988)
  expect_equal(res$summary$status, c("ok", "ok"))
})

test_that("study and registry errors are distinguished from failed designs", {
  data(smoking)
  b <- sensitivity_baseline()
  for (periods in list(numeric(), c(1988, 1989), c(1989, 1989), 2001)) {
    expect_error(synth_sensitivity(smoking, b, list(), periods), "att_periods")
  }
  expect_error(
    synth_sensitivity(smoking, b, list(a = list(), a = list()), 1989:2000),
    "names"
  )
  expect_error(
    synth_sensitivity(smoking, b, list(), 1989:2000,
      synth_args = list(X0 = matrix(1))
    ),
    "synth_args"
  )
})

test_that("post-treatment outcomes never affect fitted weights", {
  data(smoking)
  ref <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  post <- smoking$year >= 1989 & smoking$state_id == 3
  smoking$cigsale[post] <- smoking$cigsale[post] + 1000
  changed <- synth_sensitivity(
    smoking, sensitivity_baseline(), list(), 1989:2000
  )
  expect_equal(ref$weights, changed$weights)
  expect_equal(changed$summary$att - ref$summary$att, 1000)
})

test_that("custom weights cannot move to different matching variables", {
  data(smoking)
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(
    predictor = list(predictors = "beer"),
    special = list(special_predictors = list(list("cigsale", 1980, "mean"))),
    window = list(pre_periods = 1984:1988)
  ), 1989:2000, synth_args = list(custom.v = c(0.9, 0.1)))
  expect_equal(res$failures$spec_id, c("predictor", "special"))
  expect_true(all(grepl("custom.v", res$failures$message, fixed = TRUE)))
  expect_true(all(is.finite(res$summary$att[c(1, 4)])))
})

test_that("unknown exclusions and nondeterministic settings fail early", {
  data(smoking)
  baseline <- sensitivity_baseline()
  expect_error(
    synth_sensitivity(smoking, baseline, list(), 1989:2000,
      excluded_donors = 999
    ), "excluded_donors"
  )
  for (genoud in list(TRUE, 1, "TRUE", NULL, c(FALSE, FALSE))) {
    expect_error(
      synth_sensitivity(smoking, baseline, list(), 1989:2000,
        synth_args = list(genoud = genoud)
      ), "genoud"
    )
  }
  for (quadopt in list(NULL, character(), NA_character_, c("ipop", "ipop"))) {
    expect_error(
      synth_sensitivity(smoking, baseline, list(), 1989:2000,
        synth_args = list(quadopt = quadopt)
      ), "quadopt"
    )
  }
})

test_that("both plot types handle all failures and mixed results", {
  data(smoking)
  file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file)
  on.exit(
    {
      grDevices::dev.off()
      unlink(file)
    },
    add = TRUE
  )
  for (excluded in list(numeric(), 1)) {
    res <- synth_sensitivity(smoking, sensitivity_baseline(),
      list(bad = list(predictors = "absent")), 1989:2000,
      excluded_donors = excluded
    )
    expect_invisible(plot(res))
    expect_invisible(plot(res, type = "paths"))
    expect_output(print(res), "attempted")
  }
})

test_that("solver warnings retain finite estimates and diagnostics", {
  data(smoking)
  original <- synth
  testthat::local_mocked_bindings(
    synth = function(..., genoud = FALSE, quadopt = "ipop") {
      warning("solver did not converge")
      original(..., genoud = genoud, quadopt = quadopt)
    },
    .package = "Synth"
  )
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  expect_equal(res$summary$status, "warning")
  expect_true(is.finite(res$summary$att))
  expect_match(res$warnings$message, "did not converge")
  expect_equal(summary(res)$with_warnings, 1)
})

test_that("search warnings distinguish selected and unused candidates", {
  data(smoking)
  original <- synth
  for (code in c(0, 1)) {
    testthat::local_mocked_bindings(
      synth = function(..., genoud = FALSE, quadopt = "ipop") {
        fit <- original(..., genoud = genoud, quadopt = quadopt)
        fit$rgV.optim$out.list <- data.frame(convcode = c(code, 1))
        fit
      },
      .package = "Synth"
    )
    res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
    expect_equal(res$summary$status, "warning")
    expect_match(res$warnings$message, "nonconverged candidates")
    expect_match(res$warnings$message, if (code == 0) {
      "selected candidate converged"
    } else {
      "selected candidate was not confirmed converged"
    })
    expect_equal(res$fits$baseline$rgV.optim$out.list$convcode, c(code, 1))
    expect_true(is.finite(res$summary$att))
  }
})

test_that("ipop nonconvergence is exposed without changing its weights", {
  hessian <- diag(3)
  cvec <- c(-1, -2, -3)
  pars <- list(maxiter = 1)
  expect_warning(
    w <- Synth:::.solve_w_ipop(hessian, cvec, pars), "did not converge"
  )
  expect_true(all(is.finite(w)))
})

test_that("donor warnings identify search and final solves", {
  data(smoking)
  original <- Synth:::.solve_w_ipop
  for (phase in c("predictor-weight search", "final donor-weight solve")) {
    warned <- FALSE
    testthat::local_mocked_bindings(
      .solve_w_ipop = function(hessian, c_vec, pars, warning_context = NULL) {
        if (!warned && identical(warning_context, phase)) {
          pars$maxiter <- 1
          warned <<- TRUE
        }
        original(hessian, c_vec, pars, warning_context = warning_context)
      },
      .package = "Synth"
    )
    res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
    messages <- res$warnings$message[
      grepl("Donor-weight", res$warnings$message, fixed = TRUE)
    ]
    expect_true(warned)
    expect_true(length(messages) > 0)
    expect_true(all(grepl(phase, messages, fixed = TRUE)))
    expect_equal(res$summary$status, "warning")
    expect_true(is.finite(res$summary$att))
  }
})

test_that("invalid common settings fail before any estimation", {
  data(smoking)
  baseline <- sensitivity_baseline()
  common <- list(
    panel = smoking, baseline = baseline, specifications = list(),
    att_periods = 1989:2000
  )
  cases <- list(
    list(panel = as.matrix(smoking)),
    list(treatment_time = NA_real_),
    list(treatment_time = 1990),
    list(excluded_donors = "contaminated"),
    list(baseline = c(baseline, list(panel = smoking))),
    list(synth_args = list(1)),
    list(synth_args = list(genoud = TRUE)),
    list(synth_args = list(quadopt = "cvxr")),
    list(baseline = modifyList(baseline, list(unit_col = "absent"))),
    list(panel = rbind(smoking, smoking[1, ])),
    list(baseline = modifyList(baseline, list(treatment_time = 1900))),
    list(baseline = modifyList(baseline, list(plot_periods = 1980:2000)))
  )
  messages <- c(
    "panel must", "finite number", "must agree", "numeric unit ids",
    "Supply the panel", "unique names", "genoud", "ipop",
    "unit and time columns", "Unit/time pairs", "pre-treatment period",
    "plotting periods"
  )
  for (i in seq_along(cases)) {
    changes <- cases[[i]]
    args <- common
    args[names(changes)] <- changes
    expect_error(do.call(synth_sensitivity, args), messages[[i]])
  }
})

test_that("malformed overrides stay in the failure log", {
  data(smoking)
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(
    baseline = list(pre_periods = 1984:1988),
    unnamed = list(1),
    malformed = list(special_predictors = list(list("cigsale", 1980)))
  ), 1989:2000)
  expect_equal(res$summary$status, rep("failed", 3))
  expect_equal(res$failures$spec_id, c("baseline", "unnamed", "malformed"))
  expect_equal(nrow(res$paths), 0)
})

test_that("omitted pre-periods use all observed pretreatment periods", {
  data(smoking)
  baseline <- sensitivity_baseline()
  baseline$pre_periods <- NULL
  res <- synth_sensitivity(smoking, baseline, list(), 1989:2000)
  expect_equal(res$registry$baseline$pre_periods, 1970:1988)
  expect_true(is.finite(res$summary$att))
})

test_that("large finite pre-period gaps retain finite RMS summaries", {
  data(smoking)
  smoking$cigsale[smoking$state_id == 3 & smoking$year == 1970] <- 1e200
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  expect_equal(nrow(res$failures), 0)
  expect_equal(res$summary$pre_rmse / 1e200, 1 / sqrt(19))
  expect_true(is.finite(res$summary$fit_rmse))
})

test_that("large finite post-treatment gaps retain finite ATT", {
  data(smoking)
  smoking$cigsale[smoking$year >= 1989] <- 0
  cases <- list(
    list(gaps = rep(1e308, 12), expected = 1e308),
    list(gaps = rep(c(1e308, 1e308, -1e308, -1e308), 3), expected = 0),
    list(gaps = rep(0, 12), expected = 0),
    list(gaps = rep(1e-200, 12), expected = 1e-200)
  )
  for (case in cases) {
    smoking$cigsale[smoking$state_id == 3 & smoking$year >= 1989] <- case$gaps
    res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
    expect_equal(nrow(res$failures), 0)
    if (case$expected == 0) {
      expect_equal(res$summary$att, 0)
    } else {
      expect_equal(res$summary$att / case$expected, 1)
    }
    expect_equal(summary(res)$estimated, 1)
  }
})

test_that("RMS is stable across scales and nonfinite summaries fail", {
  scales <- c(
    0, .Machine$double.xmin * .Machine$double.eps, 1e-200, 1e200, 1e308
  )
  for (scale in scales) {
    expect_equal(Synth:::.sensitivity_rms(c(scale, -scale)), scale)
  }
  expect_equal(Synth:::.sensitivity_rms(c(3e200, 4e200)) / 1e200, sqrt(12.5))
  data(smoking)
  testthat::local_mocked_bindings(
    .sensitivity_rms = function(values) Inf, .package = "Synth"
  )
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  expect_equal(res$summary$status, "failed")
  expect_true(all(is.na(res$summary[c("att", "pre_rmse", "fit_rmse")])))
  expect_equal(nrow(res$paths), 0)
  expect_match(res$failures$message, "nonfinite summary")
})

test_that("dispersion is stable and excludes nonfinite estimates", {
  object <- structure(list(summary = data.frame(
    att = c(1e308, 1e308, Inf, -Inf, NA_real_), status = rep("ok", 5)
  )), class = "synth_sensitivity")
  stats <- summary(object)
  expect_equal(stats$estimated, 2)
  expect_equal(stats$positive_share, 1)
  expect_equal(stats$median, 1e308)
  expect_equal(stats$std, 0)
  object$summary$att <- c(1e200, -1e200, NA, NA, NA)
  expect_equal(summary(object)$std / 1e200, sqrt(2))
  object$summary$att <- c(1.7e308, -1.7e308, NA, NA, NA)
  expect_true(is.na(summary(object)$std))
})

validation_study <- function(panel, specifications = list(), ...) {
  synth_sensitivity(panel, sensitivity_baseline(), specifications, 1989:2000,
    validation_windows = list(1984:1988), ...
  )
}

test_that("validation matches manual training and preserves policy estimates", {
  data(smoking)
  res <- validation_study(smoking)
  baseline <- sensitivity_baseline()
  baseline$pre_periods <- 1980:1983
  baseline$special_predictors <- list(list("cigsale", 1980, "mean"))
  baseline$plot_periods <- 1984:1988
  dp <- do.call(synth_data, c(list(panel = smoking), baseline))
  fit <- synth(dp)
  expected <- as.numeric(dp$Y0plot %*% fit$solution.w)
  expect_equal(res$validation_weights$weight, as.numeric(fit$solution.w))
  expect_equal(res$validation_paths$synthetic, expected)
  error <- as.numeric(dp$Y1plot) - expected
  expect_equal(res$validation$rmse, sqrt(mean(error^2)))
  expect_equal(res$estimates$validation_rmse, res$validation$rmse)
  full <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  expect_equal(res$estimates[names(full$estimates)], full$estimates)
  expect_equal(res$weights, full$weights)
  expect_equal(res$paths, full$paths)
  expect_equal(res$metadata$treatment_time, 1989)
  expect_equal(res$baseline, sensitivity_baseline())
  expect_equal(res$validation_registry$baseline$fold_1$pre_periods, 1980:1983)
})

test_that("held-out outcomes and predictors cannot change training weights", {
  data(smoking)
  ref <- validation_study(smoking)
  held <- smoking$year >= 1984 & smoking$year < 1989
  smoking$cigsale[held & smoking$state_id == 3] <-
    smoking$cigsale[held & smoking$state_id == 3] + 1000
  smoking$retprice[smoking$year >= 1984] <-
    smoking$retprice[smoking$year >= 1984] * 1000
  changed <- validation_study(smoking)
  expect_equal(ref$validation_weights, changed$validation_weights)
  expect_equal(
    ref$validation_paths$synthetic, changed$validation_paths$synthetic
  )
  expect_gt(changed$validation$rmse, ref$validation$rmse + 900)
  expect_false(isTRUE(all.equal(ref$weights, changed$weights)))
})

test_that("post-treatment missingness cannot affect validation", {
  data(smoking)
  ref <- validation_study(smoking)
  smoking$cigsale[smoking$year >= 1989] <- NA_real_
  changed <- validation_study(smoking)
  expect_equal(ref$validation, changed$validation)
  expect_equal(ref$validation_paths, changed$validation_paths)
  expect_equal(ref$validation_weights, changed$validation_weights)
  expect_equal(changed$estimates$status, "failed")
})

test_that("rolling folds pool errors and retain incomplete designs", {
  data(smoking)
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(
    lag = list(special_predictors = list(
      list("cigsale", c(1986, 1988), "mean")
    )),
    bad = list(predictors = "absent")
  ), 1989:2000, validation_windows = list(1984:1985, 1987:1988))
  expect_equal(nrow(res$validation), 6)
  paths <- subset(res$validation_paths, spec_id == "baseline")
  expect_equal(res$estimates$validation_rmse[1], sqrt(mean(paths$gap^2)))
  expect_equal(
    subset(res$validation, spec_id == "lag")$status, c("failed", "ok")
  )
  expect_true(all(is.na(res$estimates$validation_rmse[2:3])))
  expect_true(is.finite(res$estimates$att[2]))
  failed <- subset(res$validation, status == "failed")
  expect_equal(nrow(failed), 3)
  expect_true(all(nzchar(failed$message)))
  expect_length(
    res$validation_registry$lag$fold_1$special_predictors[[1]][[2]], 0
  )
})

test_that("invalid validation windows fail before fitting", {
  data(smoking)
  for (windows in list(
    list(), list(numeric()), list(1970), list(1988:1989),
    list(c(1984, 1984)), list(1900), list(1984:1985, 1985:1986)
  )) {
    expect_error(
      synth_sensitivity(
        smoking, sensitivity_baseline(), list(), 1989:2000,
        validation_windows = windows
      ), "validation"
    )
  }
})

test_that("clipping cannot repair an inadmissible original design", {
  data(smoking)
  res <- validation_study(smoking, list(
    leaky = list(special_predictors = list(
      list("cigsale", c(1980, 1990), "mean")
    )),
    identity = list(outcome = "retprice")
  ))
  expect_equal(res$validation$status, c("ok", "failed", "failed"))
})

test_that("missing validation observations fail without shortening scoring", {
  data(smoking)
  smoking$cigsale[smoking$state_id == 1 & smoking$year == 1985] <- NA_real_
  res <- validation_study(smoking)
  expect_equal(res$validation$status, "failed")
  expect_true(is.na(res$estimates$validation_rmse))
  expect_equal(res$validation$n_validation, 5)
})

test_that("excluded units outside fold time do not invalidate clean pools", {
  data(smoking)
  extra <- smoking[smoking$state_id == 1 & smoking$year >= 1989, ]
  extra$state_id <- 999
  extra$state_name <- "Excluded"
  augmented <- rbind(smoking, extra)
  res <- validation_study(augmented, excluded_donors = 999)
  ref <- validation_study(smoking)
  expect_equal(res$validation_paths, ref$validation_paths)
  expect_equal(res$validation_weights, ref$validation_weights)
})

test_that("a declared threshold flags a subset without dropping attempts", {
  data(smoking)
  res <- validation_study(smoking, validation_max_rmse = 0)
  expect_false(res$estimates$validation_pass)
  expect_equal(summary(res)$attempted, 1)
  expect_equal(summary(res, validation_only = TRUE)$attempted, 0)
  res <- validation_study(smoking, validation_max_rmse = 1000)
  expect_true(res$estimates$validation_pass)
  expect_equal(summary(res, validation_only = TRUE)$attempted, 1)
  expect_error(
    summary(validation_study(smoking), validation_only = TRUE),
    "validation_max_rmse"
  )
  for (limit in c(-1, NA_real_, Inf)) {
    expect_error(
      validation_study(smoking, validation_max_rmse = limit),
      "validation_max_rmse"
    )
  }
  expect_error(
    synth_sensitivity(
      smoking, sensitivity_baseline(), list(), 1989:2000,
      validation_max_rmse = 1
    ), "validation"
  )
})

test_that("legacy configurations validate without changing the policy date", {
  data(smoking)
  baseline <- list(
    dependent = "cigsale", unit.variable = "state_id", time.variable = "year",
    treatment.identifier = 3, controls.identifier = c(1, 2, 4, 5),
    predictors = "retprice", predictors.op = "mean",
    time.predictors.prior = 1980:1988, time.optimize.ssr = 1980:1988,
    special.predictors = list(list("cigsale", c(1980, 1988), "mean"))
  )
  res <- synth_sensitivity(smoking, baseline, list(), 1989:2000,
    interface = "dataprep", treatment_time = 1989,
    validation_windows = list(1984:1988)
  )
  ref <- validation_study(smoking)
  expect_equal(res$validation_weights, ref$validation_weights)
  expect_equal(res$validation_paths, ref$validation_paths)
  expect_equal(res$metadata$treatment_time, 1989)
  baseline$special.predictors <- NULL
  without_special <- synth_sensitivity(
    smoking, baseline, list(), 1989:2000,
    interface = "dataprep", treatment_time = 1989,
    validation_windows = list(1984:1988)
  )
  expect_equal(without_special$validation$status, "ok")
  expect_true(is.finite(without_special$estimates$validation_rmse))
})

test_that("default pools and named treated units keep the original donors", {
  data(smoking)
  panel <- smoking[smoking$state_id %in% c(1, 2, 3, 4, 5), ]
  ref <- validation_study(panel)
  for (treated in list(3, "California")) {
    baseline <- sensitivity_baseline()
    baseline$controls <- NULL
    baseline$treated <- treated
    baseline$unit_names_col <- "state_name"
    res <- synth_sensitivity(panel, baseline, list(), 1989:2000,
      validation_windows = list(1984:1988)
    )
    expect_equal(res$validation_weights, ref$validation_weights)
    expect_equal(res$validation_paths, ref$validation_paths)
    expect_setequal(
      res$validation_registry$baseline$fold_1$controls, c(1, 2, 4, 5)
    )
  }
})

test_that("folds preserve the native minimum donor requirement", {
  data(smoking)
  panel <- smoking[smoking$state_id %in% c(1, 3), ]
  for (controls in list(NULL, 1)) {
    baseline <- sensitivity_baseline()
    baseline$controls <- controls
    res <- synth_sensitivity(panel, baseline, list(), 1989:2000,
      validation_windows = list(1984:1988)
    )
    expect_equal(res$estimates$status, "failed")
    expect_equal(res$validation$status, "failed")
    expect_true(is.na(res$estimates$validation_rmse))
    expect_match(res$validation$message, "at least two control units")
  }
})

test_that("fold warnings keep scores and preserve final-fit status", {
  data(smoking)
  original <- synth
  testthat::local_mocked_bindings(
    synth = function(..., genoud = FALSE, quadopt = "ipop") {
      args <- list(...)
      if (args$data.prep.obj$tag$synth_data_treatment_time < 1989) {
        warning("validation fit diagnostic")
      }
      original(..., genoud = genoud, quadopt = quadopt)
    },
    .package = "Synth"
  )
  res <- validation_study(smoking)
  expect_equal(res$estimates$status, "ok")
  expect_equal(res$validation$status, "warning")
  expect_equal(res$estimates$validation_status, "warning")
  expect_true(is.finite(res$estimates$validation_rmse))
  expect_match(res$validation_warnings$message, "validation fit diagnostic")
})

test_that("validation plots handle missing scores and estimates", {
  data(smoking)
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit(
    {
      grDevices::dev.off()
      unlink(path)
    },
    add = TRUE
  )
  res <- validation_study(smoking, list(bad = list(predictors = "absent")),
    validation_max_rmse = 10
  )
  expect_identical(plot(res, type = "validation"), res)
  res <- validation_study(smoking, excluded_donors = c(1, 2, 4, 5))
  expect_identical(plot(res, type = "validation"), res)
  res <- synth_sensitivity(smoking, sensitivity_baseline(), list(), 1989:2000)
  expect_error(plot(res, type = "validation"), "validation")
})

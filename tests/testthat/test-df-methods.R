test_that("as.data.frame.synth_inference returns the documented columns", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  inf <- synth_inference(fit, d, method = "conformal", alpha = 0.30)

  df <- as.data.frame(inf)
  expect_named(df, c("time", "period", "treated", "synthetic",
                     "effect", "lower", "upper"))
  expect_equal(nrow(df), length(inf$time))
  expect_s3_class(df$period, "factor")
  expect_setequal(levels(df$period), c("pre", "post", "unclassified"))
  expect_equal(attr(df, "treatment_time"), inf$treatment_time)
  expect_equal(attr(df, "method"), "conformal")
})

test_that("as.data.frame.synth_placebos returns long format with treated row", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  pl <- generate_placebos(fit, d, verbose = FALSE)

  df <- as.data.frame(pl)
  expect_named(df, c("time", "donor", "gap", "is_treated"))
  # one block per non-failed placebo + one for the treated unit
  n_per_donor <- length(pl$time)
  expected_rows <- n_per_donor * (1 + sum(!pl$failed))
  expect_equal(nrow(df), expected_rows)
  expect_true(any(df$is_treated))
  expect_equal(sum(df$is_treated), n_per_donor)
  expect_equal(attr(df, "treatment_time"), pl$treatment_time)
})

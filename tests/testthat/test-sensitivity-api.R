test_that("estimates and dispersion have distinct public names", {
  data(smoking)
  baseline <- sensitivity_baseline()
  res <- synth_sensitivity(smoking, baseline, list(), 1989:2000)
  expect_s3_class(res$estimates, "data.frame")
  expect_false("summary" %in% names(res))
  expect_identical(as.data.frame(res), res$estimates)
  expect_equal(summary(res)$attempted, nrow(res$estimates))
})

test_that("synth.tab() returns expected components", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  tab <- synth.tab(synth.res = fit, dataprep.res = d)

  expect_named(tab, c("tab.pred", "tab.v", "tab.w", "tab.loss"))

  # tab.v: rownames = predictor names
  expect_equal(nrow(tab$tab.v), nrow(d$X1))
  expect_equal(colnames(tab$tab.v), "v.weights")

  # tab.w: data frame with weights, names, numbers
  expect_s3_class(tab$tab.w, "data.frame")
  expect_equal(colnames(tab$tab.w),
               c("w.weights", "unit.names", "unit.numbers"))
  expect_equal(nrow(tab$tab.w), ncol(d$X0))

  # tab.pred: predictor x (Treated, Synthetic, Sample Mean)
  expect_equal(colnames(tab$tab.pred),
               c("Treated", "Synthetic", "Sample Mean"))
  expect_equal(nrow(tab$tab.pred), nrow(d$X1))

  # Synthetic predictor values approximately match treated for the
  # well-fit example
  diff <- abs(tab$tab.pred[, "Treated"] - tab$tab.pred[, "Synthetic"])
  expect_true(all(diff < 5))   # generous, just sanity-checking
})

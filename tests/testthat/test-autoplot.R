test_that("autoplot.synth_inference returns a ggplot", {
  skip_if_not_installed("ggplot2")
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  inf <- synth_inference(fit, d, method = "conformal", alpha = 0.30)

  p <- ggplot2::autoplot(inf)
  expect_s3_class(p, "ggplot")
})

test_that("autoplot.synth_placebos returns a ggplot", {
  skip_if_not_installed("ggplot2")
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  pl <- generate_placebos(fit, d, verbose = FALSE)

  p <- ggplot2::autoplot(pl)
  expect_s3_class(p, "ggplot")

  # mspe_threshold filter doesn't error
  p2 <- ggplot2::autoplot(pl, mspe_threshold = 5)
  expect_s3_class(p2, "ggplot")
})

test_that("autoplot.synth_inference still works when conformal_q is Inf", {
  skip_if_not_installed("ggplot2")
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  inf <- suppressWarnings(synth_inference(fit, d, method = "conformal", alpha = 0.05))
  expect_true(is.infinite(inf$conformal_q))

  p <- ggplot2::autoplot(inf)
  expect_s3_class(p, "ggplot")
})

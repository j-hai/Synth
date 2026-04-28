test_that("synth() with dataprep object converges and weights sum to 1", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)

  expect_type(fit, "list")
  expect_named(fit,
               c("solution.v", "solution.w", "loss.v", "loss.w",
                 "custom.v", "rgV.optim"))
  expect_equal(sum(fit$solution.w), 1, tolerance = 1e-6)
  expect_true(all(fit$solution.w >= 0 - 1e-6))
  expect_true(all(fit$solution.w <= 1 + 1e-6))

  # V weights should also sum to 1 after normalization in synth().
  expect_equal(sum(fit$solution.v), 1, tolerance = 1e-6)
  expect_true(all(fit$solution.v >= 0))
})

test_that("synth() matrix interface gives the same answer as dataprep interface", {
  d <- make_dataprep()
  fit_obj <- synth(d, verbose = FALSE)
  fit_mat <- synth(X1 = d$X1, X0 = d$X0,
                   Z1 = d$Z1, Z0 = d$Z0,
                   verbose = FALSE)

  expect_equal(fit_obj$solution.w, fit_mat$solution.w, tolerance = 1e-6)
  expect_equal(fit_obj$solution.v, fit_mat$solution.v, tolerance = 1e-6)
  expect_equal(fit_obj$loss.v, fit_mat$loss.v, tolerance = 1e-6)
})

test_that("synth() with custom.v skips V optimization", {
  d <- make_dataprep()
  cv <- rep(1, nrow(d$X1)) / nrow(d$X1)
  fit <- synth(d, custom.v = cv, verbose = FALSE)
  expect_equal(as.numeric(fit$solution.v), cv, tolerance = 1e-12)
  expect_null(fit$rgV.optim)
})

test_that("synth() rejects malformed inputs", {
  d <- make_dataprep()

  expect_error(
    synth(X1 = d$X1, X0 = d$X0, Z0 = d$Z0, Z1 = NULL, verbose = FALSE),
    "Z1 is missing"
  )

  # X0 with no variation across controls
  X0bad <- d$X0
  X0bad[1, ] <- 1
  expect_error(
    synth(X1 = d$X1, X0 = X0bad, Z0 = d$Z0, Z1 = d$Z1, verbose = FALSE),
    "no variation"
  )
})

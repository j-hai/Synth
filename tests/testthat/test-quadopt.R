test_that("synth() rejects deprecated quadopt = 'LowRankQP' (regression for 1.1-9 crash)", {
  d <- make_dataprep()
  expect_error(
    synth(d, quadopt = "LowRankQP", verbose = FALSE),
    "no longer supported"
  )
})

test_that("synth() rejects unknown quadopt", {
  d <- make_dataprep()
  expect_error(
    synth(d, quadopt = "newOptimizer", verbose = FALSE)
  )
})

test_that("fn.V() rejects deprecated quadopt = 'LowRankQP'", {
  d <- make_dataprep()
  big.df <- cbind(d$X0, d$X1)
  divisor <- sqrt(apply(big.df, 1, var))
  scaled <- t(t(big.df) %*% (1 / divisor *
                             diag(rep(nrow(big.df), 1))))
  X0s <- scaled[, 1:ncol(d$X0), drop = FALSE]
  X1s <- scaled[, ncol(scaled)]

  vstart <- rep(1 / nrow(d$X1), nrow(d$X1))
  expect_error(
    fn.V(variables.v = vstart, X0.scaled = X0s, X1.scaled = X1s,
         Z0 = d$Z0, Z1 = d$Z1, quadopt = "LowRankQP"),
    "no longer supported"
  )
})

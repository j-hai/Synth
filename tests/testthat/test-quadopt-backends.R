# The CVXR and torch backends are tested directly against the QP that
# arises from make_dataprep() rather than through full synth() runs.
# Calling them through synth() would invoke them on every fn.V()
# evaluation inside optimx's V-search, which is hundreds of QP solves
# and dominates check time. The QP is the same; testing the solver
# alone is what matters.

# Build the canonical QP from a fitted V on the toy panel.
.canonical_qp <- function() {
  d <- make_dataprep()
  fit <- synth(d, quadopt = "ipop", verbose = FALSE)
  big.df <- cbind(d$X0, d$X1)
  divisor <- sqrt(apply(big.df, 1, var))
  scaled <- big.df / divisor
  X0s <- scaled[, 1:ncol(d$X0), drop = FALSE]
  X1s <- as.matrix(scaled[, ncol(scaled)])
  V <- diag(as.numeric(fit$solution.v), nrow = nrow(X0s))
  H <- t(X0s) %*% V %*% X0s
  c <- as.numeric(-1 * t(X1s) %*% V %*% X0s)
  list(H = H, c = c, w_ipop = as.numeric(fit$solution.w))
}

test_that("CVXR backend agrees with ipop on the canonical QP", {
  skip_if_not_installed("CVXR")
  qp <- .canonical_qp()
  w_cvxr <- as.numeric(Synth:::.solve_w(qp$H, qp$c, quadopt = "cvxr"))

  expect_equal(sum(w_cvxr), 1, tolerance = 1e-6)
  expect_true(all(w_cvxr >= -1e-6))

  # Both solvers should reach the same minimum value (within solver
  # tolerance) even if they pick different points on the optimal
  # face of the simplex.
  obj <- function(w) as.numeric(t(w) %*% qp$H %*% w + 2 * sum(qp$c * w))
  expect_lt(obj(w_cvxr) - obj(qp$w_ipop), 1e-4)
  expect_lt(obj(qp$w_ipop) - obj(w_cvxr), 1e-4)  # both within 1e-4 of each other
})

test_that("torch backend agrees with ipop on the canonical QP", {
  skip_if_not_installed("torch")
  skip_if_not(torch::torch_is_installed(),
              "libtorch not installed; run torch::install_torch()")
  qp <- .canonical_qp()
  w_torch <- as.numeric(Synth:::.solve_w(qp$H, qp$c, quadopt = "torch"))

  expect_equal(sum(w_torch), 1, tolerance = 1e-6)
  expect_true(all(w_torch >= -1e-6))

  obj <- function(w) as.numeric(t(w) %*% qp$H %*% w + 2 * sum(qp$c * w))
  # Frank-Wolfe with exact line search converges to within ~1e-3 of
  # ipop's optimum on this small problem.
  expect_lt(abs(obj(w_torch) - obj(qp$w_ipop)), 1e-3)
})

test_that("quadopt_outer alone uses ipop for V-search and the chosen backend for final W", {
  skip_if_not_installed("CVXR")
  d <- make_dataprep()

  # If V-search were going through CVXR, this would be the slow ~150s run
  # we measured earlier on this fixture. With quadopt_outer set alone,
  # the V-search stays on ipop and only the final W solve hits CVXR.
  t0 <- Sys.time()
  fit <- synth(d, quadopt_outer = "cvxr", verbose = FALSE)
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  # Generous bound: ipop alone takes ~2s; allow 30s headroom for CI variance.
  expect_lt(dt, 30)

  # Result is still a valid simplex weight with comparable fit
  expect_equal(sum(fit$solution.w), 1, tolerance = 1e-6)
  expect_true(all(fit$solution.w >= -1e-6))

  fit_ipop <- synth(d, quadopt = "ipop", verbose = FALSE)
  pre <- which(d$tag$time.plot %in% d$tag$time.optimize.ssr)
  m_ipop  <- mean((d$Y1plot - d$Y0plot %*% fit_ipop$solution.w)[pre]^2)
  m_split <- mean((d$Y1plot - d$Y0plot %*% fit$solution.w)[pre]^2)
  expect_lt(abs(m_ipop - m_split) / max(m_ipop, 1e-8), 0.05)
})

test_that("quadopt_inner / quadopt_outer default to inheriting quadopt", {
  d <- make_dataprep()
  fit_a <- synth(d, quadopt = "ipop", verbose = FALSE)
  fit_b <- synth(d, quadopt = "ipop",
                 quadopt_inner = NULL, quadopt_outer = NULL,
                 verbose = FALSE)
  expect_equal(fit_a$solution.w, fit_b$solution.w, tolerance = 1e-12)
})

test_that(".solve_w() rejects unknown backends with the canonical message", {
  H <- matrix(c(2, 0, 0, 2), 2, 2)
  c <- c(-1, -1)
  expect_error(Synth:::.solve_w(H, c, quadopt = "newOptimizer"),
               "Unknown quadopt")
  expect_error(Synth:::.solve_w(H, c, quadopt = "LowRankQP"),
               "no longer supported")
})

test_that(".solve_w_cvxr errors gracefully when CVXR is unavailable", {
  skip_if(requireNamespace("CVXR", quietly = TRUE),
          "CVXR is installed; this test only runs when it is missing")
  H <- matrix(c(2, 0, 0, 2), 2, 2)
  c <- c(-1, -1)
  expect_error(Synth:::.solve_w_cvxr(H, c, list()),
               "CVXR is not installed")
})

test_that(".solve_w_torch errors gracefully when torch is unavailable", {
  skip_if(requireNamespace("torch", quietly = TRUE),
          "torch is installed; this test only runs when it is missing")
  H <- matrix(c(2, 0, 0, 2), 2, 2)
  c <- c(-1, -1)
  expect_error(Synth:::.solve_w_torch(H, c, list()),
               "torch is not installed")
})

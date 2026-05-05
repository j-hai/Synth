test_that("synth_inference() with method='conformal' returns the expected shape", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  # The toy fixture has 7 SSR-window years; alpha = 0.30 gives k = 6 <= 7
  # so conformal_q is finite.
  inf <- synth_inference(fit, d, method = "conformal", alpha = 0.30)

  expect_s3_class(inf, c("synth_conformal", "synth_inference"))
  expect_named(inf,
               c("method", "alpha", "time", "pre_idx", "post_idx",
                 "treatment_time", "treated", "synthetic", "effect",
                 "pre_mspe", "post_mspe", "mspe_ratio",
                 "intervals", "conformal_q"))
  expect_equal(inf$method, "conformal")

  # geometry
  expect_equal(length(inf$time), nrow(inf$intervals))
  expect_true(all(inf$intervals[, "lower"] <= inf$synthetic + 1e-12))
  expect_true(all(inf$intervals[, "upper"] >= inf$synthetic - 1e-12))

  # conformal_q identity (finite-sample (n+1) rank)
  r <- sort(abs(inf$effect[inf$pre_idx]))
  n <- length(r)
  k <- ceiling((n + 1) * (1 - inf$alpha))
  expect_lte(k, n)  # the toy fixture should not be too small
  expect_equal(inf$conformal_q, r[k])

  # mspe_ratio identity
  expect_equal(inf$mspe_ratio, inf$post_mspe / inf$pre_mspe)
})

test_that("post window respects treatment_time, excluding pre-SSR-window pre-treatment years", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)

  # The toy fixture has time.plot = 1984:1996 and time.optimize.ssr =
  # 1984:1990. Pre and post should fully partition the plot horizon
  # in this case (no pre-SSR-window years), and post should start at
  # 1991, not at any year in 1984:1990.
  inf <- suppressWarnings(synth_inference(fit, d))
  expect_equal(inf$treatment_time, 1991)
  expect_equal(d$tag$time.plot[min(inf$post_idx)], 1991)
  expect_false(any(d$tag$time.plot[inf$post_idx] %in% d$tag$time.optimize.ssr))

  # Now simulate a pre-SSR-window scenario with a fabricated dataprep
  # whose time.plot starts before time.optimize.ssr.
  d2 <- d
  d2$tag$time.plot <- c(1980:1983, d$tag$time.plot)
  # Pad Y1plot/Y0plot to match. Use first row of original data so
  # gaps for the bogus years are well-defined; only the index logic
  # is being tested.
  d2$Y1plot <- rbind(matrix(d$Y1plot[1, ], nrow = 4, ncol = ncol(d$Y1plot),
                            byrow = TRUE), d$Y1plot)
  d2$Y0plot <- rbind(matrix(d$Y0plot[1, ], nrow = 4, ncol = ncol(d$Y0plot),
                            byrow = TRUE), d$Y0plot)

  inf2 <- suppressWarnings(synth_inference(fit, d2))
  expect_equal(inf2$treatment_time, 1991)
  # The four pre-SSR-window years (1980-1983) are NOT classified as post
  expect_false(any(d2$tag$time.plot[inf2$post_idx] %in% 1980:1983))
  # And not classified as pre either (pre is the SSR window)
  expect_false(any(d2$tag$time.plot[inf2$pre_idx] %in% 1980:1983))
})

test_that("conformal returns Inf when sample size is too small for alpha", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)

  # SSR window is 1984:1990 (n = 7). alpha = 0.05 needs k = ceil(8*0.95) = 8 > 7.
  expect_warning(
    inf <- synth_inference(fit, d, method = "conformal", alpha = 0.05),
    "too small for finite-sample"
  )
  expect_true(is.infinite(inf$conformal_q))
})

test_that("synth_inference() with method='parametric' uses qnorm * sd(gap_pre)", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  inf <- synth_inference(fit, d, method = "parametric", alpha = 0.05)

  expect_s3_class(inf, c("synth_parametric", "synth_inference"))
  expect_equal(inf$method, "parametric")
  expect_equal(inf$sigma_pre, stats::sd(inf$effect[inf$pre_idx]))

  half <- stats::qnorm(1 - inf$alpha / 2) * inf$sigma_pre
  expect_equal(as.numeric(inf$intervals[, "upper"] - inf$synthetic),
               rep(half, length(inf$time)))
})

test_that("synth_inference() rejects malformed inputs", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)

  expect_error(synth_inference(NULL, d), "synth.res")
  expect_error(synth_inference(list(), d), "solution.w")
  expect_error(synth_inference(fit, NULL), "dataprep.res")
  expect_error(synth_inference(fit, d, alpha = 0),    "alpha")
  expect_error(synth_inference(fit, d, alpha = 1.5),  "alpha")
  expect_error(synth_inference(fit, d, alpha = c(0.05, 0.1)), "alpha")
})

test_that("print() and plot() methods run on both subclasses", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)

  for (m in c("conformal", "parametric")) {
    # Default alpha = 0.05 triggers the small-sample warning on the
    # toy fixture for the conformal method; that path is itself tested
    # elsewhere. Use alpha = 0.30 here so the print/plot smoke run is
    # exercising the finite-q path.
    inf <- synth_inference(fit, d, method = m, alpha = 0.30)
    expect_output(print(inf), "Synthetic control inference")

    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    expect_silent(plot(inf, Legend = NA))
  }
})

test_that("plot() handles Inf intervals (small-sample conformal) without erroring", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  inf <- suppressWarnings(synth_inference(fit, d, method = "conformal", alpha = 0.05))
  expect_true(is.infinite(inf$conformal_q))

  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_silent(plot(inf, Legend = NA))
})

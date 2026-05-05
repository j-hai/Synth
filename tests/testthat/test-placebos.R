test_that("generate_placebos() returns one placebo fit per donor", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  pl <- generate_placebos(fit, d, verbose = FALSE)

  expect_s3_class(pl, "synth_placebos")
  expect_equal(length(pl$placebos), ncol(d$X0))
  expect_equal(length(pl$donor_names), ncol(d$X0))
  expect_equal(length(pl$failed), ncol(d$X0))
  expect_equal(length(pl$time), length(d$tag$time.plot))

  # New: treatment_time defaults to max(SSR window) + 1
  expect_equal(pl$treatment_time, max(d$tag$time.optimize.ssr) + 1)
  # And post window starts at treatment_time
  expect_equal(d$tag$time.plot[min(pl$post_idx)], pl$treatment_time)

  # treated summary matches what synth_inference would compute on the real fit
  inf <- suppressWarnings(synth_inference(fit, d, method = "conformal"))
  expect_equal(pl$treated$gap, inf$effect)
  expect_equal(pl$treated$mspe_ratio, inf$mspe_ratio)
})

test_that("mspe_test() p-value matches the empirical rank by construction", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  pl <- generate_placebos(fit, d, verbose = FALSE)
  expect_equal(pl$treatment_time, 1991)
  res <- mspe_test(pl)

  expect_named(res,
               c("mspe_ratio_treated", "mspe_ratios_placebos",
                 "pvalue", "n_valid_placebos"))
  expect_true(res$pvalue > 0 && res$pvalue <= 1)

  valid <- !is.na(res$mspe_ratios_placebos)
  expected <- mean(c(res$mspe_ratio_treated,
                     res$mspe_ratios_placebos[valid]) >= res$mspe_ratio_treated)
  expect_equal(res$pvalue, expected)
})

test_that("placebo donor swap is column-swap symmetric", {
  d <- make_dataprep()
  swapped <- Synth:::.swap_donor_into_treated(d, 1)

  # New treated comes from donor 1
  expect_equal(swapped$X1[, 1], d$X0[, 1])
  expect_equal(swapped$Z1[, 1], d$Z0[, 1])
  expect_equal(swapped$Y1plot[, 1], d$Y0plot[, 1])

  # Original treated takes donor 1's column slot
  expect_equal(swapped$X0[, 1], d$X1[, 1])
  expect_equal(swapped$Z0[, 1], d$Z1[, 1])
  expect_equal(swapped$Y0plot[, 1], d$Y1plot[, 1])

  # Other donor columns are unchanged
  expect_equal(swapped$X0[, -1], d$X0[, -1])
})

test_that("keep_fits = TRUE stores full synth() output per donor", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  pl <- generate_placebos(fit, d, verbose = FALSE, keep_fits = TRUE)

  expect_true(all(vapply(pl$placebos, function(p) !is.null(p$fit), logical(1))))
  # Each fit should be a synth() return shape
  expect_true(all(vapply(pl$placebos,
                         function(p) is.list(p$fit) && !is.null(p$fit$solution.w),
                         logical(1))))
})

test_that("error_message is NA on success and a captured message on failure", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  pl <- generate_placebos(fit, d, verbose = FALSE)

  ok <- !pl$failed
  expect_true(all(is.na(vapply(pl$placebos[ok],
                               function(p) p$error_message, character(1)))))
  # If anything happened to fail, its message should be a non-empty string.
  if (any(pl$failed)) {
    msgs <- vapply(pl$placebos[pl$failed],
                   function(p) p$error_message, character(1))
    expect_true(all(nchar(msgs) > 0))
  }
})

test_that("plot/print/mspe_plot methods run without error", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)
  pl <- generate_placebos(fit, d, verbose = FALSE)

  expect_output(print(pl), "Synth placebos")

  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_silent(plot_placebos(pl))
  expect_silent(plot(pl))
  expect_silent(mspe_plot(pl))
})

test_that("generate_placebos() rejects malformed inputs", {
  d <- make_dataprep()
  fit <- synth(d, verbose = FALSE)

  expect_error(generate_placebos(NULL, d),  "synth.res")
  expect_error(generate_placebos(fit, NULL), "dataprep.res")

  # Single-donor pool — placebos are not meaningful
  d_one <- d
  d_one$X0     <- d_one$X0[, 1, drop = FALSE]
  d_one$Z0     <- d_one$Z0[, 1, drop = FALSE]
  d_one$Y0plot <- d_one$Y0plot[, 1, drop = FALSE]
  expect_error(generate_placebos(fit, d_one), "at least 2 donors")
})

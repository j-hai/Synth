test_that(".period_indices() default treatment_time = max(SSR) + 1", {
  d <- make_dataprep()
  p <- Synth:::.period_indices(d)
  expect_equal(p$treatment_time, max(d$tag$time.optimize.ssr) + 1)
  expect_equal(d$tag$time.plot[min(p$post_idx)], p$treatment_time)
  expect_true(all(d$tag$time.plot[p$pre_idx] %in% d$tag$time.optimize.ssr))
  expect_equal(p$n_unclassified, 0)
})

test_that(".period_indices() respects an explicit treatment_time", {
  d <- make_dataprep()
  p <- Synth:::.period_indices(d, treatment_time = 1993)
  expect_equal(p$treatment_time, 1993)
  expect_equal(d$tag$time.plot[min(p$post_idx)], 1993)
  # Years 1991, 1992 fall between SSR window and treatment_time → unclassified
  expect_equal(p$n_unclassified, 2)
})

test_that(".period_indices() warns when treatment_time falls inside SSR window", {
  d <- make_dataprep()
  expect_warning(
    Synth:::.period_indices(d, treatment_time = 1989),
    "inside time.optimize.ssr"
  )
})

test_that(".period_indices() warns when no post periods result", {
  d <- make_dataprep()
  expect_warning(
    p <- Synth:::.period_indices(d, treatment_time = max(d$tag$time.plot) + 1),
    "zero post-treatment periods"
  )
  expect_length(p$post_idx, 0)
})

test_that(".period_indices() rejects non-numeric / non-finite / out-of-range treatment_time", {
  d <- make_dataprep()
  expect_error(Synth:::.period_indices(d, treatment_time = "1990"), "single finite numeric")
  expect_error(Synth:::.period_indices(d, treatment_time = c(1990, 1991)), "single finite numeric")
  expect_error(Synth:::.period_indices(d, treatment_time = NA_real_), "single finite numeric")
  expect_error(Synth:::.period_indices(d, treatment_time = Inf), "single finite numeric")
  expect_error(Synth:::.period_indices(d, treatment_time = 1900), "outside the panel")
  expect_error(Synth:::.period_indices(d, treatment_time = 2050), "outside the panel")
})

test_that(".period_indices() handles a pre-SSR-window scenario", {
  d <- make_dataprep()
  # Fabricate a pre-SSR-window panel: extend time.plot back to 1980
  d2 <- d
  d2$tag$time.plot <- c(1980:1983, d$tag$time.plot)
  p <- Synth:::.period_indices(d2)
  # 1980-1983 are pre-treatment but before the SSR window → unclassified
  expect_equal(p$n_unclassified, 4)
  expect_false(any(d2$tag$time.plot[p$pre_idx] %in% 1980:1983))
  expect_false(any(d2$tag$time.plot[p$post_idx] %in% 1980:1983))
})

test_that(".period_indices() errors when pre_idx is empty", {
  d <- make_dataprep()
  # Fabricate a dataprep where time.plot does not intersect time.optimize.ssr
  d2 <- d
  d2$tag$time.plot <- 1991:1996
  expect_error(
    Synth:::.period_indices(d2),
    "pre-period is empty"
  )
})

test_that(".mspe_summary() returns Inf when pre_mspe == 0", {
  effect <- c(0, 0, 0, 0, 1, 2, 3)  # zero pre, nonzero post
  expect_warning(
    s <- Synth:::.mspe_summary(effect, pre_idx = 1:4, post_idx = 5:7),
    "exactly zero"
  )
  expect_equal(s$pre_mspe, 0)
  expect_true(is.infinite(s$mspe_ratio))
})

test_that(".mspe_summary() returns NA mspe_ratio when no post periods", {
  effect <- c(1, 2, 3)
  s <- Synth:::.mspe_summary(effect, pre_idx = 1:3, post_idx = integer(0))
  expect_true(is.na(s$post_mspe))
  expect_true(is.na(s$mspe_ratio))
})

test_that(".period_indices() prefers stored synth_data_treatment_time (regression)", {
  # When synth_data() runs with treatment_time strictly later than
  # max(time.optimize.ssr) + 1 -- e.g. SSR window deliberately
  # excludes the last pre-treatment years -- the old default
  # (max(time.pre) + 1) inferred the wrong cutoff and classified
  # genuine pre-treatment years as post-period. The stored tag now
  # takes precedence.
  d <- make_dataprep()
  d$tag$time.plot                 <- 1960:1980
  d$tag$time.optimize.ssr         <- 1960:1965
  d$tag$synth_data_treatment_time <- 1970
  p <- Synth:::.period_indices(d)
  expect_equal(p$treatment_time, 1970)
  # Years 1966-1969 are pre-treatment but outside the SSR window;
  # they must NOT show up in post_idx.
  expect_false(any(d$tag$time.plot[p$post_idx] %in% 1966:1969))
  expect_true(all(d$tag$time.plot[p$post_idx] >= 1970))
})

test_that(".period_indices() falls back to max(SSR)+1 without stored value", {
  d <- make_dataprep()
  d$tag$synth_data_treatment_time <- NULL  # explicitly absent
  p <- Synth:::.period_indices(d)
  expect_equal(p$treatment_time, max(d$tag$time.optimize.ssr) + 1)
})

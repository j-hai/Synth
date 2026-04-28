test_that("synth(verbose = FALSE) produces no console output", {
  d <- make_dataprep()
  out <- capture.output(synth(d, verbose = FALSE))
  expect_length(out, 0L)
})

test_that("synth(verbose = TRUE) prints the MSPE summary block", {
  d <- make_dataprep()
  out <- capture.output(synth(d, verbose = TRUE))
  expect_true(any(grepl("MSPE", out)))
  expect_true(any(grepl("solution.v", out)))
  expect_true(any(grepl("solution.w", out)))
})

test_that("synth() matrix interface is silent at verbose = FALSE", {
  d <- make_dataprep()
  out <- capture.output(
    synth(X1 = d$X1, X0 = d$X0, Z1 = d$Z1, Z0 = d$Z0, verbose = FALSE)
  )
  expect_length(out, 0L)
})

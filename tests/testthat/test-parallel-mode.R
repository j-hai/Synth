test_that(".resolve_parallel_mode() handles all input shapes", {
  expect_equal(Synth:::.resolve_parallel_mode(FALSE),       "none")
  expect_equal(Synth:::.resolve_parallel_mode("none"),      "none")
  expect_equal(Synth:::.resolve_parallel_mode("snow"),      "snow")

  # On a unix-like platform TRUE / "auto" → multicore.
  if (.Platform$OS.type != "windows") {
    expect_equal(Synth:::.resolve_parallel_mode(TRUE),      "multicore")
    expect_equal(Synth:::.resolve_parallel_mode("auto"),    "multicore")
    expect_equal(Synth:::.resolve_parallel_mode("multicore"), "multicore")
  } else {
    expect_equal(Synth:::.resolve_parallel_mode(TRUE),      "snow")
    expect_equal(Synth:::.resolve_parallel_mode("auto"),    "snow")
    expect_error(Synth:::.resolve_parallel_mode("multicore"),
                 "not available on Windows")
  }

  expect_error(Synth:::.resolve_parallel_mode("foo"), "Unknown parallel")
  expect_error(Synth:::.resolve_parallel_mode(c("snow", "multicore")), "Unknown parallel")
})

# =============================================================================
# Phase 2 fix-specific tests for Synth 1.1-10
# =============================================================================
# Each test isolates one audit fix.
# =============================================================================

pkg_root <- getwd()
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))

templib <- tempfile("synth_phase2_lib_")
dir.create(templib)
res <- system2(file.path(R.home("bin"), "R"),
               c("CMD", "INSTALL", "--no-multiarch",
                 "-l", shQuote(templib), shQuote(pkg_root)),
               stdout = TRUE, stderr = TRUE)
if (!is.null(attr(res, "status")) && attr(res, "status") != 0) {
  cat(res, sep = "\n"); stop("install failed")
}
.libPaths(c(templib, .libPaths()))
suppressPackageStartupMessages(library(Synth, lib.loc = templib))
cat("Loaded Synth", as.character(packageVersion("Synth")),
    "for Phase 2 tests\n\n")

.fail <- 0L; .pass <- 0L
expect <- function(cond, label) {
  if (isTRUE(cond)) { cat(sprintf("  [PASS] %s\n", label)); .pass <<- .pass + 1L }
  else              { cat(sprintf("  [FAIL] %s\n", label)); .fail <<- .fail + 1L }
}

data(synth.data)

# Common dataprep object — same shape as s1 in 01_capture_baseline.R
dataprep.out <- dataprep(
  foo = synth.data,
  predictors = c("X1", "X2", "X3"),
  predictors.op = "mean",
  dependent = "Y",
  unit.variable = "unit.num",
  time.variable = "year",
  special.predictors = list(
    list("Y", 1991, "mean"),
    list("Y", 1985, "mean"),
    list("Y", 1980, "mean")
  ),
  treatment.identifier = 7,
  controls.identifier = c(29, 2, 13, 17, 32, 38),
  time.predictors.prior = c(1984:1989),
  time.optimize.ssr = c(1984:1990),
  unit.names.variable = "name",
  time.plot = 1984:1996
)

# =============================================================================
# Fix 1: LowRankQP fall-through now errors instead of crashing cryptically
# =============================================================================
cat("--- Fix 1: LowRankQP fail-fast ---\n")
{
  err <- tryCatch(
    synth(dataprep.out, quadopt = "LowRankQP", verbose = FALSE),
    error = function(e) e
  )
  expect(inherits(err, "error"),
         "synth(quadopt='LowRankQP') errors")
  expect(grepl("no longer supported", conditionMessage(err)),
         "error message mentions 'no longer supported'")
}

# =============================================================================
# Fix: silent default
# =============================================================================
cat("\n--- Fix: synth(verbose=FALSE) is silent ---\n")
{
  out <- capture.output(
    synth.out <- synth(dataprep.out, verbose = FALSE)
  )
  expect(length(out) == 0L,
         "synth(verbose=FALSE) produces no console output")

  out2 <- capture.output(
    synth.out2 <- synth(dataprep.out, verbose = TRUE)
  )
  expect(length(out2) > 0L,
         "synth(verbose=TRUE) produces console output")
  expect(any(grepl("MSPE", out2)),
         "verbose=TRUE shows MSPE summary")
}

# =============================================================================
# Fix: error message for too-few control units in Z0
# =============================================================================
cat("\n--- Fix: Z0 error message ---\n")
{
  d <- dataprep.out
  d$Z0 <- d$Z0[, 1, drop = FALSE]   # collapse to single column
  err <- tryCatch(
    synth(X0 = d$X0, X1 = d$X1, Z0 = d$Z0, Z1 = d$Z1, verbose = FALSE),
    error = function(e) e
  )
  expect(inherits(err, "error"),
         "single-column Z0 errors")
  expect(grepl("control units", conditionMessage(err)),
         "error mentions 'control units' (not 'treated unit')")
}

# =============================================================================
# Regression: numerical equivalence with previous version still holds
# =============================================================================
cat("\n--- Regression: known scenario reproduces ---\n")
{
  set.seed(20260428L)
  fit <- synth(dataprep.out, verbose = FALSE)
  expect(abs(fit$loss.v - 4.7048) < 0.01,
         "loss.v ≈ 4.705 (matches frozen 1.1-9 baseline)")
  expect(abs(sum(fit$solution.w) - 1) < 1e-8,
         "solution.w sums to 1")
}

# =============================================================================
# Summary
# =============================================================================
cat(sprintf("\n%d passed, %d failed\n", .pass, .fail))
if (.fail > 0L) quit(save = "no", status = 1L)
quit(save = "no", status = 0L)

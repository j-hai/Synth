# =============================================================================
# Regression check: current dev source vs. frozen Synth 1.1-9 baseline
# =============================================================================
#
# Mirrors the ebal/dev/02_regression_check.R contract:
#   * Install the current source into a temp lib
#   * Re-run the same scenarios with the same seeds
#   * Compare element-wise to dev/baseline_1.1-9.rds within tolerance
#   * Additive-tolerant: new keys are allowed; removed keys ARE flagged
#
# How to run:
#   Rscript dev/02_regression_check.R               # default tol 1e-8
#   Rscript dev/02_regression_check.R --tol=1e-12   # tighter
#   Rscript dev/02_regression_check.R --verbose
#
# Note: the default tolerance is 1e-8 (looser than ebal's 1e-10) because
# Synth's optimization uses ipop/Nelder-Mead which can have more
# floating-point variability across runs.
# =============================================================================

# ---- args -------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
opt_tol <- 1e-8
opt_verbose <- FALSE
for (a in args) {
  if (grepl("^--tol=", a)) opt_tol <- as.numeric(sub("^--tol=", "", a))
  if (a == "--verbose") opt_verbose <- TRUE
}

# Scenarios known to differ from 1.1-9 due to intentional fixes.
expected_diffs <- list(
  # filled in as Phase 2 fixes land
)

# ---- locate paths -----------------------------------------------------------
pkg_root <- getwd()
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))
baseline_rds <- file.path(pkg_root, "dev", "baseline_1.1-9.rds")
stopifnot(file.exists(baseline_rds))

# ---- install current source into isolated lib -------------------------------
templib <- tempfile("synth_dev_lib_")
dir.create(templib)
cat("Installing current source from", pkg_root, "into temp lib...\n")
res <- system2(
  file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", "--no-multiarch", "-l", shQuote(templib),
    shQuote(pkg_root)),
  stdout = TRUE, stderr = TRUE
)
if (!is.null(attr(res, "status")) && attr(res, "status") != 0) {
  cat(res, sep = "\n"); stop("R CMD INSTALL failed")
}

.libPaths(c(templib, .libPaths()))
suppressPackageStartupMessages(library(Synth, lib.loc = templib))
cat("Loaded Synth", as.character(packageVersion("Synth")),
    "from temp lib\n\n")

# ---- run scenarios (mirror 01_capture_baseline.R) ---------------------------
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

run_scenarios <- function() {
  out <- list()

  data(synth.data)

  # s1
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
  set.seed(20260428L)
  synth.out <- synth(dataprep.out, verbose = FALSE)
  tab.out <- synth.tab(dataprep.res = dataprep.out, synth.res = synth.out)
  out$s1_toy_panel <- list(
    inputs = list(treatment.identifier = 7,
                  controls.identifier  = c(29, 2, 13, 17, 32, 38)),
    dataprep_X0 = dataprep.out$X0,
    dataprep_X1 = dataprep.out$X1,
    dataprep_Z0 = dataprep.out$Z0,
    dataprep_Z1 = dataprep.out$Z1,
    solution_v  = synth.out$solution.v,
    solution_w  = synth.out$solution.w,
    loss_v      = synth.out$loss.v,
    loss_w      = synth.out$loss.w,
    tab_v       = tab.out$tab.v,
    tab_w       = tab.out$tab.w,
    tab_pred    = tab.out$tab.pred
  )

  # s2
  dataprep.out <- dataprep(
    foo = synth.data,
    predictors = c("X1", "X2", "X3"),
    predictors.op = "mean",
    dependent = "Y",
    unit.variable = "unit.num",
    time.variable = "year",
    treatment.identifier = 7,
    controls.identifier = c(29, 2, 13, 17, 32, 38),
    time.predictors.prior = c(1984:1989),
    time.optimize.ssr = c(1984:1990),
    unit.names.variable = "name",
    time.plot = 1984:1996
  )
  custom.v <- rep(1, nrow(dataprep.out$X1)) / nrow(dataprep.out$X1)
  set.seed(20260428L)
  synth.out <- synth(dataprep.out, custom.v = custom.v, verbose = FALSE)
  out$s2_custom_v <- list(
    custom.v   = custom.v,
    solution_v = synth.out$solution.v,
    solution_w = synth.out$solution.w,
    loss_v     = synth.out$loss.v,
    loss_w     = synth.out$loss.w
  )

  # s3
  d1 <- dataprep(
    foo = synth.data,
    predictors = c("X1", "X2", "X3"),
    predictors.op = "mean",
    dependent = "Y",
    unit.variable = "unit.num",
    time.variable = "year",
    treatment.identifier = 7,
    controls.identifier = c(29, 2, 13, 17, 32, 38),
    time.predictors.prior = c(1984:1989),
    time.optimize.ssr = c(1984:1990),
    unit.names.variable = "name",
    time.plot = 1984:1996
  )
  set.seed(20260428L)
  synth.out <- synth(X1 = d1$X1, X0 = d1$X0,
                     Z1 = d1$Z1, Z0 = d1$Z0,
                     verbose = FALSE)
  out$s3_matrix_interface <- list(
    solution_v = synth.out$solution.v,
    solution_w = synth.out$solution.w,
    loss_v     = synth.out$loss.v,
    loss_w     = synth.out$loss.w
  )

  out
}

current  <- suppressMessages(run_scenarios())
baseline <- readRDS(baseline_rds)

# ---- compare ----------------------------------------------------------------
compare_one <- function(cur, base, path = "", tol = opt_tol) {
  if (is.list(cur) && is.list(base)) {
    diffs <- character()
    for (k in names(base)) {
      diffs <- c(diffs, compare_one(cur[[k]], base[[k]],
                                    paste0(path, "$", k), tol))
    }
    return(diffs)
  }
  if (is.numeric(cur) && is.numeric(base)) {
    if (length(cur) != length(base)) {
      return(sprintf("%s: length differs (cur=%d base=%d)", path,
                     length(cur), length(base)))
    }
    if (length(cur) == 0L) return(character())
    md <- max(abs(cur - base), na.rm = TRUE)
    if (anyNA(cur) != anyNA(base)) {
      return(sprintf("%s: NA pattern differs", path))
    }
    if (is.finite(md) && md > tol) {
      return(sprintf("%s: max |diff| = %.3g > tol=%.1g", path, md, tol))
    }
    return(character())
  }
  if (is.character(cur) && is.character(base)) {
    if (!identical(cur, base)) return(sprintf("%s: character mismatch", path))
    return(character())
  }
  if (!identical(cur, base)) return(sprintf("%s: identical() failed", path))
  character()
}

cat("Tolerance:", opt_tol, "\n")
cat("Comparing", length(current), "scenarios:\n\n")

unexpected <- 0L
expected_changed <- 0L
ok <- 0L
for (nm in names(baseline)) {
  if (!nm %in% names(current)) {
    cat(sprintf("  [MISSING] %s\n", nm))
    unexpected <- unexpected + 1L
    next
  }
  diffs <- compare_one(current[[nm]], baseline[[nm]], path = nm)
  if (length(diffs) == 0L) {
    cat(sprintf("  [OK]      %s\n", nm)); ok <- ok + 1L
  } else if (nm %in% names(expected_diffs)) {
    cat(sprintf("  [EXPECTED] %s — %s\n", nm, expected_diffs[[nm]]))
    if (opt_verbose) for (d in diffs) cat(sprintf("            %s\n", d))
    expected_changed <- expected_changed + 1L
  } else {
    cat(sprintf("  [DIFF]    %s\n", nm))
    for (d in diffs) cat(sprintf("            %s\n", d))
    unexpected <- unexpected + 1L
  }
}

cat(sprintf("\nSummary: %d ok, %d expected-changed, %d unexpected\n",
            ok, expected_changed, unexpected))
if (unexpected > 0L) quit(save = "no", status = 1L)
quit(save = "no", status = 0L)

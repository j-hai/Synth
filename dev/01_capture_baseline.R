# =============================================================================
# Capture golden-baseline outputs from Synth 1.1-9 (frozen reference)
# =============================================================================
#
# Purpose:
#   Install the frozen 1.1-9 tarball into a TEMPORARY library and run a
#   fixed-seed set of toy examples that exercise dataprep() + synth() and
#   the associated tab/plot helpers. Save outputs to RDS so later phases
#   (audit fixes, refactors) can compare against them.
#
# How to run:
#   Rscript dev/01_capture_baseline.R
#
# Outputs:
#   dev/baseline_1.1-9.rds — list of named results, see scenarios below
#   dev/baseline_1.1-9.log — sessionInfo and timing
# =============================================================================

# ---- locate paths -----------------------------------------------------------
script_dir <- if (sys.nframe() > 0) {
  tryCatch(dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE)),
           error = function(e) getwd())
} else getwd()
if (!file.exists(file.path(script_dir, "Synth_1.1-9_baseline.tar.gz"))) {
  if (file.exists("dev/Synth_1.1-9_baseline.tar.gz")) {
    script_dir <- file.path(getwd(), "dev")
  }
}
tarball <- file.path(script_dir, "Synth_1.1-9_baseline.tar.gz")
stopifnot(file.exists(tarball))

baseline_rds <- file.path(script_dir, "baseline_1.1-9.rds")
baseline_log <- file.path(script_dir, "baseline_1.1-9.log")

# ---- install into isolated library -----------------------------------------
templib <- tempfile("synth_baseline_lib_")
dir.create(templib)
cat("Installing", basename(tarball), "into", templib, "\n")
install.packages(tarball, repos = NULL, type = "source", lib = templib,
                 quiet = TRUE, INSTALL_opts = "--no-multiarch")

.libPaths(c(templib, .libPaths()))
suppressPackageStartupMessages(library(Synth, lib.loc = templib))
stopifnot(packageVersion("Synth") == "1.1-9")

# ---- deterministic test scenarios ------------------------------------------
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

scenarios <- list()

# Scenario 1: canonical toy panel from dataprep()/synth() Rd example -------
{
  data(synth.data)
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
  scenarios$s1_toy_panel <- list(
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
}

# Scenario 2: custom.v supplied — bypasses optimization ----------------------
{
  data(synth.data)
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
  scenarios$s2_custom_v <- list(
    custom.v   = custom.v,
    solution_v = synth.out$solution.v,
    solution_w = synth.out$solution.w,
    loss_v     = synth.out$loss.v,
    loss_w     = synth.out$loss.w
  )
}

# Scenario 3: matrix interface (no dataprep.obj) -----------------------------
{
  data(synth.data)
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
  scenarios$s3_matrix_interface <- list(
    solution_v = synth.out$solution.v,
    solution_w = synth.out$solution.w,
    loss_v     = synth.out$loss.v,
    loss_w     = synth.out$loss.w
  )
}

# ---- save -------------------------------------------------------------------
saveRDS(scenarios, baseline_rds, version = 2)
sink(baseline_log)
cat("Synth version: ", as.character(packageVersion("Synth")), "\n", sep = "")
cat("R version:     ", R.version.string, "\n", sep = "")
cat("captured at:   ", format(Sys.time(), tz = "UTC", usetz = TRUE), "\n", sep = "")
cat("RDS:           ", baseline_rds, "\n", sep = "")
cat("scenarios:     ", length(scenarios), " (", paste(names(scenarios), collapse = ", "), ")\n", sep = "")
cat("\n--- sessionInfo ---\n")
print(sessionInfo())
sink()

cat("Wrote", baseline_rds, "\n")
cat("Wrote", baseline_log, "\n")

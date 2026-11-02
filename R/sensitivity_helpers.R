.sensitivity_interface <- function(interface) {
  if (interface == "synth_data") {
    list(
      unit = "unit_col", time = "time_col", controls = "controls",
      periods = "pre_periods", special = "special_predictors",
      plot = "plot_periods", treatment = "treatment_time",
      prepare = function(panel, cfg) {
        do.call(synth_data, c(list(panel = panel), cfg))
      },
      forecast = function(panel, cfg, cutoff) {
        if (is.null(cfg$controls)) {
          treated <- cfg$treated
          if (!is.numeric(treated)) {
            index <- match(treated, panel[[cfg$unit_names_col]])
            treated <- panel[[cfg$unit_col]][index]
          }
          cfg$controls <- setdiff(unique(panel[[cfg$unit_col]]), treated)
        }
        cfg$treatment_time <- cutoff
        cfg
      }
    )
  } else {
    list(
      unit = "unit.variable", time = "time.variable",
      controls = "controls.identifier",
      periods = c("time.predictors.prior", "time.optimize.ssr"),
      special = "special.predictors", plot = "time.plot", treatment = NULL,
      prepare = function(panel, cfg) {
        do.call(dataprep, c(list(foo = panel), cfg))
      },
      forecast = function(panel, cfg, cutoff) cfg
    )
  }
}

.sensitivity_periods <- function(cfg, context) {
  check <- function(x, name) {
    if (!length(x) || anyNA(x) || anyDuplicated(x) ||
          any(!x %in% context$times) || any(x >= context$treatment_time)) {
      stop(paste(
        name, "must contain unique observed strictly pre-treatment periods"
      ))
    }
  }
  for (field in context$layout$periods) check(cfg[[field]], field)
  for (special in cfg[[context$layout$special]]) {
    if (length(special) != 3) {
      stop("Each special predictor must have three entries")
    }
    check(special[[2]], context$layout$special)
  }
}

.sensitivity_fit <- function(panel, cfg, context, configure, summarize) {
  fit_warnings <- character()
  n_donors <- NA_integer_
  output <- tryCatch(withCallingHandlers(
    {
      cfg <- configure(cfg)
      .sensitivity_periods(cfg, context)
      dp <- context$layout$prepare(panel, cfg)
      donor_ids <- as.numeric(colnames(dp$Y0plot))
      n_donors <- length(donor_ids)
      if (any(donor_ids %in% context$excluded_donors)) {
        stop("Donor pool contains a declared treated or contaminated donor")
      }
      if (!all(is.finite(c(dp$Y0plot, dp$Y1plot)))) {
        stop("All common trajectory periods require finite outcomes")
      }
      if (!identical(
        as.numeric(rownames(dp$Y0plot)), as.numeric(context$times)
      )) {
        stop("Prepared data changed the common trajectory periods")
      }
      fit <- do.call(synth, c(list(data.prep.obj = dp), context$synth_args))
      optimizer <- if (is.list(fit$rgV.optim)) fit$rgV.optim$out.list
      if (!is.null(optimizer) && !is.null(optimizer$convcode) &&
            any(optimizer$convcode != 0, na.rm = TRUE)) {
        selected <- if (isTRUE(optimizer$convcode[1] == 0)) {
          "converged"
        } else {
          "was not confirmed converged"
        }
        warning(paste(
          "Predictor-weight search included nonconverged candidates;",
          "the selected candidate", selected
        ))
      }
      donor_order <- match(colnames(dp$Y0plot), rownames(fit$solution.w))
      w <- fit$solution.w[donor_order, 1]
      if (!all(is.finite(c(w, unlist(fit$solution.v))))) {
        stop("Estimator returned nonfinite weights")
      }
      synthetic <- as.numeric(dp$Y0plot %*% w)
      observed <- as.numeric(dp$Y1plot)
      gap <- observed - synthetic
      if (!all(is.finite(gap))) {
        stop("Estimator returned a nonfinite trajectory")
      }
      statistics <- summarize(gap, dp$tag$time.optimize.ssr)
      if (!all(is.finite(unlist(statistics)))) {
        stop("Estimator returned nonfinite summary statistics")
      }
      list(
        statistics = statistics, fit = fit, prepared = dp,
        paths = data.frame(
          time = context$times, observed = observed,
          synthetic = synthetic, gap = gap
        ),
        weights = data.frame(
          donor = colnames(dp$Y0plot), weight = as.numeric(w)
        )
      )
    },
    warning = function(w) {
      fit_warnings <<- c(fit_warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  ), error = identity)
  diagnostics <- list(
    config = cfg, n_donors = n_donors, warnings = fit_warnings
  )
  if (inherits(output, "error")) {
    c(diagnostics, list(
      status = "failed", exception_type = class(output)[1],
      message = conditionMessage(output)
    ))
  } else {
    c(diagnostics, list(
      status = if (length(fit_warnings)) "warning" else "ok"
    ), output)
  }
}

synth_sensitivity <- function(panel, baseline, specifications, att_periods,
                              synth_args = list(), excluded_donors = numeric(),
                              interface = c("synth_data", "dataprep"),
                              treatment_time = baseline$treatment_time) {
  interface <- match.arg(interface)
  if (!is.data.frame(panel) || !is.list(baseline) || !is.list(specifications)) {
    stop(
      "panel must be a data.frame; baseline and specifications must be lists"
    )
  }
  if (length(treatment_time) != 1 || !is.numeric(treatment_time) ||
        !is.finite(treatment_time)) {
    stop("treatment_time must be one finite number")
  }
  if (interface == "synth_data" &&
        !identical(treatment_time, baseline$treatment_time)) {
    stop("treatment_time must agree with baseline$treatment_time")
  }
  if (!is.numeric(excluded_donors) || anyNA(excluded_donors)) {
    stop("excluded_donors must contain numeric unit ids")
  }
  if (any(c("foo", "panel") %in% names(baseline))) {
    stop("Supply the panel through panel, not baseline")
  }
  if (length(synth_args) && (
    is.null(names(synth_args)) || any(!nzchar(names(synth_args))) ||
      anyDuplicated(names(synth_args))
  )) {
    stop("synth_args must have unique names")
  }
  permitted <- setdiff(
    names(formals(synth)), c("data.prep.obj", "X0", "X1", "Z0", "Z1", "...")
  )
  if (length(setdiff(names(synth_args), permitted))) {
    stop("synth_args may only contain fixed solver settings")
  }
  defaults <- lapply(
    formals(synth)[permitted], eval,
    envir = environment(synth)
  )
  defaults[names(synth_args)] <- synth_args
  synth_args <- defaults
  # Random search needs an explicit per-fit RNG contract in a later interface.
  if (!identical(synth_args$genoud, FALSE)) {
    stop("genoud is not supported by this deterministic runner")
  }
  if (!identical(synth_args$quadopt, "ipop") || any(vapply(
    synth_args[c("quadopt_inner", "quadopt_outer")],
    function(x) !is.null(x) && !identical(x, "ipop"), logical(1)
  ))) {
    stop("The initial sensitivity interface supports quadopt = 'ipop' only")
  }

  unit_col <- baseline[[
    if (interface == "synth_data") "unit_col" else "unit.variable"
  ]]
  time_col <- baseline[[
    if (interface == "synth_data") "time_col" else "time.variable"
  ]]
  if (length(unit_col) != 1 || length(time_col) != 1 ||
        !all(c(unit_col, time_col) %in% names(panel))) {
    stop("baseline must name the unit and time columns")
  }
  identifiers <- panel[c(unit_col, time_col)]
  if (anyNA(identifiers) || anyDuplicated(identifiers)) {
    stop("Unit/time pairs must be nonmissing and unique")
  }
  if (any(!excluded_donors %in% panel[[unit_col]])) {
    stop("excluded_donors contains unit ids absent from the panel")
  }
  times <- sort(unique(panel[[time_col]]))
  pre <- times[times < treatment_time]
  if (!length(pre)) stop("At least one pre-treatment period is required")
  if (!length(att_periods) || anyNA(att_periods) ||
        anyDuplicated(att_periods) || any(!att_periods %in% times) ||
        any(att_periods < treatment_time)) {
    stop("att_periods must be unique observed post-treatment periods")
  }
  spec_names <- names(specifications)
  if (length(specifications) && (
    is.null(spec_names) || anyNA(spec_names) ||
      any(!nzchar(spec_names)) || anyDuplicated(spec_names)
  )) {
    stop("Specification names must be unique and nonempty")
  }
  if (!"baseline" %in% spec_names) {
    specifications <- c(list(baseline = list()), specifications)
  }

  base <- baseline
  if (interface == "synth_data") {
    if (is.null(base$pre_periods)) base$pre_periods <- pre
    if (is.null(base$plot_periods)) base$plot_periods <- times
    fields <- c(
      "controls", "predictors", "predictors.op", "special_predictors",
      "pre_periods"
    )
    period_fields <- "pre_periods"
    special_field <- "special_predictors"
    plot_field <- "plot_periods"
  } else {
    if (is.null(base$time.plot)) base$time.plot <- times
    fields <- c(
      "controls.identifier", "predictors", "predictors.op",
      "special.predictors", "time.predictors.prior", "time.optimize.ssr"
    )
    period_fields <- c("time.predictors.prior", "time.optimize.ssr")
    special_field <- "special.predictors"
    plot_field <- "time.plot"
  }
  if (!identical(as.numeric(base[[plot_field]]), as.numeric(times))) {
    stop("Baseline plotting periods must cover the full observed trajectory")
  }
  registry <- lapply(specifications, function(overrides) {
    cfg <- base
    cfg[names(overrides)] <- overrides
    cfg
  })
  summaries <- list()
  paths <- data.frame(
    spec_id = character(), time = numeric(), observed = numeric(),
    synthetic = numeric(), gap = numeric()
  )
  weights <- data.frame(
    spec_id = character(), donor = character(), weight = numeric()
  )
  failures <- data.frame(
    spec_id = character(), exception_type = character(), message = character()
  )
  warning_log <- data.frame(
    spec_id = character(), warning_type = character(), message = character()
  )
  fits <- list()
  prepared <- list()

  check_periods <- function(x, name) {
    if (!length(x) || anyNA(x) || anyDuplicated(x) || any(!x %in% times) ||
          any(x >= treatment_time)) {
      stop(paste(
        name, "must contain unique observed strictly pre-treatment periods"
      ))
    }
  }
  for (name in names(registry)) {
    cfg <- registry[[name]]
    overrides <- specifications[[name]]
    row <- data.frame(
      spec_id = name, att = NA_real_, pre_rmse = NA_real_,
      fit_rmse = NA_real_, n_donors = NA_integer_, status = "failed"
    )
    fit_warnings <- character()
    output <- tryCatch(withCallingHandlers(
      {
        if (!is.list(overrides) || (length(overrides) && (
          is.null(names(overrides)) || any(!nzchar(names(overrides))) ||
            anyDuplicated(names(overrides))
        ))) {
          stop("Overrides must be a named list")
        }
        fixed <- setdiff(names(overrides), fields)
        unchanged <- vapply(
          fixed, function(k) identical(overrides[[k]], base[[k]]), logical(1)
        )
        if (any(!unchanged)) {
          stop(paste(
            "Only design fields may vary;",
            "study identity and solver settings are fixed"
          ))
        }
        if (name == "baseline" && length(overrides)) {
          stop("The baseline cannot contain overrides")
        }
        if (!is.null(synth_args$custom.v) &&
              any(c("predictors", special_field) %in% names(overrides))) {
          stop("custom.v requires fixed predictors and special predictors")
        }
        for (field in period_fields) check_periods(cfg[[field]], field)
        for (special in cfg[[special_field]]) {
          if (length(special) != 3) {
            stop("Each special predictor must have three entries")
          }
          check_periods(special[[2]], special_field)
        }
        controls <- cfg[[
          if (interface == "synth_data") "controls" else "controls.identifier"
        ]]
        if (anyDuplicated(controls)) stop("Donor identifiers must be unique")
        dp <- if (interface == "synth_data") {
          do.call(synth_data, c(list(panel = panel), cfg))
        } else {
          do.call(dataprep, c(list(foo = panel), cfg))
        }
        donor_ids <- as.numeric(colnames(dp$Y0plot))
        row$n_donors <- length(donor_ids)
        if (any(donor_ids %in% excluded_donors)) {
          stop("Donor pool contains a declared treated or contaminated donor")
        }
        if (!all(is.finite(c(dp$Y0plot, dp$Y1plot)))) {
          stop("All common trajectory periods require finite outcomes")
        }
        if (!identical(as.numeric(rownames(dp$Y0plot)), as.numeric(times))) {
          stop("Prepared data changed the common trajectory periods")
        }
        fit <- do.call(synth, c(list(data.prep.obj = dp), synth_args))
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
        fit_periods <- match(dp$tag$time.optimize.ssr, times)
        statistics <- list(
          att = mean(gap[match(att_periods, times)]),
          pre_rmse = .sensitivity_rms(gap[match(pre, times)]),
          fit_rmse = .sensitivity_rms(gap[fit_periods])
        )
        if (!all(is.finite(unlist(statistics)))) {
          stop("Estimator returned nonfinite summary statistics")
        }
        row[names(statistics)] <- statistics
        list(
          row = row, fit = fit, dp = dp,
          paths = data.frame(
            spec_id = name, time = times, observed = observed,
            synthetic = synthetic, gap = gap
          ),
          weights = data.frame(
            spec_id = name, donor = colnames(dp$Y0plot), weight = as.numeric(w)
          )
        )
      },
      warning = function(w) {
        fit_warnings <<- c(fit_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ), error = function(e) e)
    if (inherits(output, "error")) {
      failures <- rbind(failures, data.frame(
        spec_id = name,
        exception_type = class(output)[1], message = conditionMessage(output)
      ))
    } else {
      row <- output$row
      row$status <- if (length(fit_warnings)) "warning" else "ok"
      fits[[name]] <- output$fit
      prepared[[name]] <- output$dp
      paths <- rbind(paths, output$paths)
      weights <- rbind(weights, output$weights)
    }
    if (length(fit_warnings)) {
      warning_log <- rbind(warning_log, data.frame(
        spec_id = name,
        warning_type = "warning", message = fit_warnings
      ))
    }
    summaries[[name]] <- row
  }
  summary_table <- do.call(rbind, summaries)
  rownames(summary_table) <- NULL
  structure(
    list(
      summary = summary_table, paths = paths, weights = weights,
      failures = failures, warnings = warning_log, registry = registry,
      baseline = baseline, fits = fits, prepared = prepared,
      metadata = list(
        treatment_time = treatment_time, att_periods = att_periods,
        pre_periods = pre, synth_args = synth_args,
        excluded_donors = excluded_donors, interface = interface,
        version = as.character(utils::packageVersion("Synth"))
      )
    ),
    class = "synth_sensitivity"
  )
}

.sensitivity_rms <- function(values) {
  scale <- max(abs(values))
  if (scale == 0) {
    return(0)
  }
  scale * sqrt(mean((values / scale)^2))
}

.sensitivity_sd <- function(values) {
  if (length(values) < 2) {
    return(NA_real_)
  }
  # Remove the common level before scaling to preserve small differences.
  shifted <- values - values[1]
  if (all(is.finite(shifted))) {
    values <- shifted
  }
  scale <- max(abs(values))
  if (scale == 0) {
    return(0)
  }
  value <- scale * stats::sd(values / scale)
  if (is.finite(value)) value else NA_real_
}

summary.synth_sensitivity <- function(object, ...) {
  effects <- object$summary$att[is.finite(object$summary$att)]
  data.frame(
    attempted = nrow(object$summary), estimated = length(effects),
    failed = sum(object$summary$status == "failed"),
    with_warnings = sum(object$summary$status == "warning"),
    min = if (length(effects)) min(effects) else NA_real_,
    median = if (length(effects)) stats::median(effects) else NA_real_,
    max = if (length(effects)) max(effects) else NA_real_,
    std = .sensitivity_sd(effects),
    positive_share = if (length(effects)) mean(effects > 0) else NA_real_,
    negative_share = if (length(effects)) mean(effects < 0) else NA_real_,
    zero_share = if (length(effects)) mean(effects == 0) else NA_real_
  )
}

print.synth_sensitivity <- function(x, ...) {
  cat("Synthetic control specification sensitivity\n")
  print(summary(x), row.names = FALSE)
  invisible(x)
}

as.data.frame.synth_sensitivity <- function(x, row.names = NULL,
                                            optional = FALSE, ...) {
  as.data.frame(x$summary, row.names = row.names, optional = optional, ...)
}

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

  layout <- .sensitivity_interface(interface)
  unit_col <- baseline[[layout$unit]]
  time_col <- baseline[[layout$time]]
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
  if (!is.null(layout$treatment) && is.null(base[[layout$periods]])) {
    base[[layout$periods]] <- pre
  }
  if (is.null(base[[layout$plot]])) base[[layout$plot]] <- times
  fields <- c(
    layout$controls, "predictors", "predictors.op",
    layout$special, layout$periods
  )
  if (!identical(as.numeric(base[[layout$plot]]), as.numeric(times))) {
    stop("Baseline plotting periods must cover the full observed trajectory")
  }
  context <- list(
    layout = layout, unit_col = unit_col, time_col = time_col,
    times = times, treatment_time = treatment_time,
    synth_args = synth_args, excluded_donors = excluded_donors
  )
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

  check_design <- function(cfg, overrides, name) {
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
          any(c("predictors", layout$special) %in% names(overrides))) {
      stop("custom.v requires fixed predictors and special predictors")
    }
    if (anyDuplicated(cfg[[layout$controls]])) {
      stop("Donor identifiers must be unique")
    }
  }
  summarize <- function(gap, fit_periods) {
    list(
      att = mean(gap[match(att_periods, times)]),
      pre_rmse = .sensitivity_rms(gap[match(pre, times)]),
      fit_rmse = .sensitivity_rms(gap[match(fit_periods, times)])
    )
  }
  for (name in names(registry)) {
    cfg <- registry[[name]]
    overrides <- specifications[[name]]
    row <- data.frame(
      spec_id = name, att = NA_real_, pre_rmse = NA_real_,
      fit_rmse = NA_real_, n_donors = NA_integer_, status = "failed"
    )
    output <- .sensitivity_fit(
      panel, cfg, context,
      configure = function(cfg) {
        check_design(cfg, overrides, name)
        cfg
      },
      summarize = summarize
    )
    row$n_donors <- output$n_donors
    row$status <- output$status
    if (output$status == "failed") {
      failures <- rbind(failures, data.frame(
        spec_id = name, exception_type = output$exception_type,
        message = output$message
      ))
    } else {
      row[names(output$statistics)] <- output$statistics
      fits[[name]] <- output$fit
      prepared[[name]] <- output$prepared
      paths <- rbind(paths, cbind(spec_id = name, output$paths))
      weights <- rbind(weights, cbind(spec_id = name, output$weights))
    }
    if (length(output$warnings)) {
      warning_log <- rbind(warning_log, data.frame(
        spec_id = name, warning_type = "warning", message = output$warnings
      ))
    }
    summaries[[name]] <- row
  }
  estimates <- do.call(rbind, summaries)
  rownames(estimates) <- NULL
  structure(
    list(
      estimates = estimates, paths = paths, weights = weights,
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
  effects <- object$estimates$att[is.finite(object$estimates$att)]
  data.frame(
    attempted = nrow(object$estimates), estimated = length(effects),
    failed = sum(object$estimates$status == "failed"),
    with_warnings = sum(object$estimates$status == "warning"),
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
  as.data.frame(x$estimates, row.names = row.names, optional = optional, ...)
}

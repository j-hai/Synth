.sensitivity_windows <- function(windows, pre, limit) {
  if (
    !is.null(limit) && (length(limit) != 1 || !is.numeric(limit) ||
                          !is.finite(limit) || limit < 0)
  ) {
    stop("validation_max_rmse must be finite and nonnegative")
  }
  if (is.null(windows)) {
    if (!is.null(limit)) stop("validation_max_rmse requires validation_windows")
    return(list())
  }
  if (!is.list(windows) || !length(windows)) {
    stop("validation_windows must be a nonempty list of period vectors")
  }
  seen <- numeric()
  for (window in windows) {
    if (
      !is.numeric(window) || !length(window) || anyNA(window) ||
        anyDuplicated(window) || any(!window %in% pre) ||
        min(window) <= min(pre) || any(window %in% seen)
    ) {
      stop(paste(
        "validation_windows must contain unique, disjoint pre-treatment",
        "periods with earlier training observations"
      ))
    }
    seen <- c(seen, window)
  }
  windows <- lapply(windows, sort)
  windows[order(vapply(windows, min, numeric(1)))]
}

.sensitivity_validate <- function(
  panel, registry, specifications, windows, times, unit_col, time_col,
  period_fields, special_field, plot_field, interface, synth_args,
  excluded_donors, check_design) {
  rows <- list()
  paths <- data.frame(
    spec_id = character(), fold_id = character(), time = numeric(),
    observed = numeric(), synthetic = numeric(), gap = numeric()
  )
  weights <- data.frame(
    spec_id = character(), fold_id = character(), donor = character(),
    weight = numeric()
  )
  warning_log <- data.frame(
    spec_id = character(), fold_id = character(), warning_type = character(),
    message = character()
  )
  configurations <- fits <- prepared <- list()
  for (name in names(registry)) {
    configurations[[name]] <- fits[[name]] <- prepared[[name]] <- list()
    for (number in seq_along(windows)) {
      window <- windows[[number]]
      fold <- paste0("fold_", number)
      train <- times[times < min(window)]
      cfg <- registry[[name]]
      row <- data.frame(
        spec_id = name, fold_id = fold, rmse = NA_real_,
        n_train = length(train), n_validation = length(window),
        status = "failed",
        exception_type = NA_character_, message = NA_character_
      )
      fit_warnings <- character()
      result <- NULL
      error <- tryCatch(withCallingHandlers(
        {
          check_design(cfg, specifications[[name]], name)
          for (field in period_fields) {
            cfg[[field]] <- cfg[[field]][cfg[[field]] < min(window)]
          }
          if (length(cfg[[special_field]])) {
            cfg[[special_field]] <- lapply(
              cfg[[special_field]], function(special) {
                special[[2]] <- special[[2]][special[[2]] < min(window)]
                special
              }
            )
          }
          cfg[[plot_field]] <- c(train, window)
          if (interface == "synth_data") {
            if (is.null(cfg$controls)) {
              treated <- cfg$treated
              if (!is.numeric(treated)) {
                index <- match(treated, panel[[cfg$unit_names_col]])
                treated <- panel[[unit_col]][index]
              }
              cfg$controls <- setdiff(unique(panel[[unit_col]]), treated)
            }
            cfg$treatment_time <- min(window)
          }
          fold_panel <- panel[
            panel[[time_col]] %in% c(train, window), , drop = FALSE
          ]
          result <- synth_sensitivity(
            fold_panel, cfg, list(), window,
            synth_args = synth_args,
            excluded_donors = intersect(
              excluded_donors, unique(fold_panel[[unit_col]])
            ),
            interface = interface, treatment_time = min(window)
          )
          row$status <- result$summary$status
          if (row$status == "failed") {
            row$exception_type <- result$failures$exception_type
            row$message <- result$failures$message
          } else {
            predicted <- result$paths[
              result$paths$time %in% window, , drop = FALSE
            ]
            predicted$spec_id <- name
            predicted$fold_id <- fold
            paths <- rbind(paths, predicted[names(paths)])
            row$rmse <- .sensitivity_rms(predicted$gap)
            donor_weights <- result$weights
            donor_weights$spec_id <- name
            donor_weights$fold_id <- fold
            weights <- rbind(weights, donor_weights[names(weights)])
            fits[[name]][[fold]] <- result$fits$baseline
            prepared[[name]][[fold]] <- result$prepared$baseline
          }
          NULL
        },
        warning = function(w) {
          fit_warnings <<- c(fit_warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ), error = identity)
      if (inherits(error, "error")) {
        row$status <- "failed"
        row$rmse <- NA_real_
        row$exception_type <- class(error)[1]
        row$message <- conditionMessage(error)
      }
      if (!is.null(result) && nrow(result$warnings)) {
        logged <- result$warnings
        logged$spec_id <- name
        logged$fold_id <- fold
        warning_log <- rbind(warning_log, logged[names(warning_log)])
      }
      if (length(fit_warnings)) {
        warning_log <- rbind(warning_log, data.frame(
          spec_id = name, fold_id = fold, warning_type = "warning",
          message = fit_warnings
        ))
        if (row$status == "ok") row$status <- "warning"
      }
      configurations[[name]][[fold]] <- cfg
      rows[[length(rows) + 1]] <- row
    }
  }
  table <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      spec_id = character(), fold_id = character(), rmse = numeric(),
      n_train = integer(), n_validation = integer(), status = character(),
      exception_type = character(), message = character()
    )
  }
  rownames(table) <- rownames(paths) <- rownames(weights) <- NULL
  list(
    validation = table, validation_paths = paths, validation_weights = weights,
    validation_warnings = warning_log, validation_registry = configurations,
    validation_fits = fits, validation_prepared = prepared
  )
}

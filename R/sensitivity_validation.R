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

.sensitivity_validate <- function(panel, registry, specifications, windows,
                                  context, check_design) {
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
  layout <- context$layout
  for (name in names(registry)) {
    configurations[[name]] <- fits[[name]] <- prepared[[name]] <- list()
    for (number in seq_along(windows)) {
      window <- windows[[number]]
      fold <- paste0("fold_", number)
      train <- context$times[context$times < min(window)]
      fold_context <- context
      fold_context$times <- c(train, window)
      fold_context$treatment_time <- min(window)
      row <- data.frame(
        spec_id = name, fold_id = fold, rmse = NA_real_,
        n_train = length(train), n_validation = length(window),
        status = "failed", exception_type = NA_character_,
        message = NA_character_
      )
      output <- .sensitivity_fit(
        panel[
          panel[[context$time_col]] %in% fold_context$times, , drop = FALSE
        ],
        registry[[name]], fold_context,
        configure = function(cfg) {
          check_design(cfg, specifications[[name]], name)
          .sensitivity_periods(cfg, context)
          for (field in layout$periods) {
            cfg[[field]] <- cfg[[field]][cfg[[field]] < min(window)]
          }
          if (length(cfg[[layout$special]])) {
            cfg[[layout$special]] <- lapply(
              cfg[[layout$special]], function(special) {
                special[[2]] <- special[[2]][special[[2]] < min(window)]
                special
              }
            )
          }
          cfg[[layout$plot]] <- fold_context$times
          layout$forecast(panel, cfg, min(window))
        },
        summarize = function(gap, fit_periods) {
          list(rmse = .sensitivity_rms(gap[match(window, fold_context$times)]))
        }
      )
      row$status <- output$status
      if (output$status == "failed") {
        row$exception_type <- output$exception_type
        row$message <- output$message
      } else {
        row$rmse <- output$statistics$rmse
        predicted <- output$paths[output$paths$time %in% window, , drop = FALSE]
        paths <- rbind(paths, cbind(spec_id = name, fold_id = fold, predicted))
        weights <- rbind(weights, cbind(
          spec_id = name, fold_id = fold, output$weights
        ))
        fits[[name]][[fold]] <- output$fit
        prepared[[name]][[fold]] <- output$prepared
      }
      if (length(output$warnings)) {
        warning_log <- rbind(warning_log, data.frame(
          spec_id = name, fold_id = fold, warning_type = "warning",
          message = output$warnings
        ))
      }
      configurations[[name]][[fold]] <- output$config
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

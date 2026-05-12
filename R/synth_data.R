synth_data <-
function(panel,
         outcome,
         treated,
         controls = NULL,
         unit_col,
         time_col,
         treatment_time,
         predictors = NULL,
         predictors.op = "mean",
         special_predictors = list(),
         pre_periods = NULL,
         plot_periods = NULL,
         unit_names_col = NULL)
  {
    # Friendly wrapper around dataprep(). The goal is a one-line entry point
    # that picks sensible defaults for the most common case (single treated
    # unit, single treatment date), with `controls = NULL` defaulting to
    # "all other units in the panel".

    if (!is.data.frame(panel))
      stop("\n panel must be a data.frame \n")
    if (missing(unit_col) || missing(time_col))
      stop("\n unit_col and time_col are required \n")
    for (col in c(outcome, unit_col, time_col, predictors))
      if (!is.null(col) && !(col %in% names(panel)))
        stop(sprintf("\n column \"%s\" not found in panel \n", col))
    if (!is.null(unit_names_col) && !(unit_names_col %in% names(panel)))
      stop(sprintf("\n unit_names_col \"%s\" not found in panel \n", unit_names_col))
    if (!is.numeric(treatment_time) || length(treatment_time) != 1 ||
        !is.finite(treatment_time))
      stop("\n treatment_time must be a single finite numeric value \n")
    if (!is.numeric(panel[[time_col]]))
      stop(sprintf("\n time_col \"%s\" must be numeric \n", time_col))

    # Resolve treated and controls. Accept either the unit identifier
    # (numeric, matching unit_col) or a unit name (matching unit_names_col).
    .resolve_unit <- function(x) {
      if (is.numeric(x)) {
        if (!all(x %in% unique(panel[[unit_col]])))
          stop(sprintf("\n unit id %s not found in column \"%s\" \n",
                       paste(setdiff(x, unique(panel[[unit_col]])),
                             collapse = ", "), unit_col))
        return(as.numeric(x))
      }
      if (is.character(x)) {
        if (is.null(unit_names_col))
          stop("\n unit names supplied but unit_names_col is NULL; pass numeric ids or set unit_names_col \n")
        m <- match(x, panel[[unit_names_col]])
        if (any(is.na(m)))
          stop(sprintf("\n name(s) %s not found in column \"%s\" \n",
                       paste(x[is.na(m)], collapse = ", "), unit_names_col))
        # Take the first occurrence of each name
        idx <- vapply(x, function(nm) which(panel[[unit_names_col]] == nm)[1],
                      integer(1))
        return(as.numeric(panel[[unit_col]][idx]))
      }
      stop("\n unit identifier must be numeric or character \n")
    }
    treated.id <- .resolve_unit(treated)
    if (length(treated.id) != 1)
      stop("\n exactly one treated unit must be supplied \n")

    if (is.null(controls)) {
      controls.id <- setdiff(unique(panel[[unit_col]]), treated.id)
      if (length(controls.id) < 2)
        stop("\n need at least 2 control units in the panel \n")
    } else {
      controls.id <- .resolve_unit(controls)
      if (treated.id %in% controls.id)
        stop("\n treated unit must not appear in controls \n")
    }
    controls.id <- as.numeric(sort(controls.id))

    # Resolve time windows. plot_periods defaults to the observed
    # panel times (not min:max, which would invent unobserved periods
    # on gapped/biennial panels and trigger dataprep() failures);
    # pre_periods to all observed times strictly before treatment_time.
    all.times <- sort(unique(panel[[time_col]]))
    if (is.null(plot_periods))
      plot_periods <- all.times
    if (is.null(pre_periods))
      pre_periods <- all.times[all.times < treatment_time]
    if (length(pre_periods) < 2)
      stop("\n need at least 2 pre-treatment periods (pre_periods has fewer than 2) \n")
    if (any(pre_periods >= treatment_time))
      warning("pre_periods contains values >= treatment_time")

    # Build the dataprep() call.
    # Translate "no entries supplied" into the values dataprep() actually
    # accepts: NULL for special.predictors (an empty list raises
    # 'subscript out of bounds' inside dataprep); NA for the no-names
    # case (NULL fails dataprep's TRUE/FALSE branch).
    sp_arg <- if (length(special_predictors) == 0) NULL else special_predictors
    uname_arg <- if (is.null(unit_names_col)) NA else unit_names_col

    dp <- dataprep(
      foo                    = panel,
      predictors             = predictors,
      predictors.op          = predictors.op,
      dependent              = outcome,
      unit.variable          = unit_col,
      time.variable          = time_col,
      special.predictors     = sp_arg,
      treatment.identifier   = treated.id,
      controls.identifier    = controls.id,
      time.predictors.prior  = pre_periods,
      time.optimize.ssr      = pre_periods,
      unit.names.variable    = uname_arg,
      time.plot              = plot_periods
    )
    # Carry the treatment_time and the original call for round-trip
    # debugging / downstream defaults.
    dp$tag$synth_data_treatment_time <- treatment_time
    attr(dp, "synth_data_call") <- match.call()
    dp
  }

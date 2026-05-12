# Internal: classify time.plot into pre, post, and unclassified periods.
#
# Pre  = times in dataprep.res$tag$time.optimize.ssr (the SSR window where
#        the synthetic was actually fit).
# Post = times >= treatment_time. If treatment_time is NULL, defaults to
#        max(time.optimize.ssr) + 1.
# Unclassified = pre-treatment plot years before the SSR window
#                (e.g. 1955-1959 in the basque example with
#                 time.optimize.ssr = 1960:1969). These are excluded from
#                both pre and post — including them in post would inflate
#                post_mspe and bias placebo p-values; including them in
#                pre would mix non-fit residuals into conformal calibration.
#
# Validates treatment_time hard:
#   * numeric scalar, finite
#   * within range(time.plot) (or one beyond max(time.plot), which simply
#     means "no post period at all")
#   * warns if treatment_time falls inside time.optimize.ssr
#   * warns if no post periods result

.period_indices <-
function(dataprep.res, treatment_time = NULL)
  {
    if (is.null(dataprep.res) || is.list(dataprep.res) == FALSE || is.null(dataprep.res$tag))
      stop("\n dataprep.res does not look like a dataprep() output: missing tag \n")

    time.plot <- dataprep.res$tag$time.plot
    time.pre  <- dataprep.res$tag$time.optimize.ssr
    if (is.null(time.plot) || is.null(time.pre))
      stop("\n dataprep.res$tag is missing time.plot or time.optimize.ssr \n")

    # Default treatment_time: prefer the value the user passed to
    # synth_data() (stashed on the tag) so synth_inference(fit, dp)
    # works without a redundant treatment_time argument. Fall back to
    # max(SSR window) + 1 only when no stored value is available --
    # that fallback breaks panels where the SSR window deliberately
    # excludes the last pre-treatment years (e.g. basque pre = 1960:1965
    # with treatment_time = 1970).
    if (is.null(treatment_time)) {
      stored <- dataprep.res$tag$synth_data_treatment_time
      treatment_time <- if (!is.null(stored)) stored else max(time.pre) + 1
    } else {
      if (!is.numeric(treatment_time) || length(treatment_time) != 1 ||
          !is.finite(treatment_time))
        stop("\n treatment_time must be a single finite numeric value \n")
      if (treatment_time < min(time.plot) || treatment_time > max(time.plot) + 1)
        stop(sprintf(
          "\n treatment_time = %g is outside the panel (time.plot = [%g, %g]) \n",
          treatment_time, min(time.plot), max(time.plot)))
      if (treatment_time %in% time.pre)
        warning(sprintf(
          "treatment_time = %g falls inside time.optimize.ssr; the post-period will start at the same year used for SSR fitting",
          treatment_time))
    }

    pre.idx  <- which(time.plot %in% time.pre)
    post.idx <- setdiff(which(time.plot >= treatment_time), pre.idx)
    n.unclassified <- length(time.plot) - length(pre.idx) - length(post.idx)

    if (length(pre.idx) == 0)
      stop("\n time.plot does not include any of the SSR optimization periods (time.optimize.ssr); pre-period is empty and no inference is possible. \n")

    if (length(post.idx) == 0)
      warning(sprintf(
        "treatment_time = %g produces zero post-treatment periods; post_mspe and mspe_ratio will be NA",
        treatment_time))

    list(
      time_plot      = time.plot,
      pre_idx        = pre.idx,
      post_idx       = post.idx,
      treatment_time = treatment_time,
      n_unclassified = n.unclassified
    )
  }

# Internal: compute MSPE summary, handling pre_mspe == 0 explicitly.
# Returns a list with pre_mspe, post_mspe, mspe_ratio.
.mspe_summary <-
function(effect, pre_idx, post_idx)
  {
    pre.mspe  <- mean(effect[pre_idx]^2)
    post.mspe <- if (length(post_idx) > 0) mean(effect[post_idx]^2) else NA_real_
    mspe.ratio <- if (length(post_idx) == 0) {
      NA_real_
    } else if (pre.mspe == 0) {
      warning("pre-period MSPE is exactly zero (synthetic perfectly tracks treated); mspe_ratio is undefined and reported as Inf")
      Inf
    } else {
      post.mspe / pre.mspe
    }
    list(pre_mspe = pre.mspe, post_mspe = post.mspe, mspe_ratio = mspe.ratio)
  }

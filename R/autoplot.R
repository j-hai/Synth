# Silence the R CMD check lint about `.data` (ggplot2's NSE pronoun).
utils::globalVariables(".data")

# autoplot() methods for synth_inference and synth_placebos. Loaded
# only when the user has ggplot2 attached, so the package itself
# does not pull ggplot2 as a hard dependency.
#
# autoplot is the generic from the `ggplot2` (and `generics`) package;
# we register methods here without importing the generic so that
# users see them when they `library(ggplot2)`. The S3method directive
# in NAMESPACE points ggplot2's autoplot generic at our methods.

autoplot.synth_inference <-
function(object, ...)
  {
    if (!requireNamespace("ggplot2", quietly = TRUE))
      stop("ggplot2 is required for autoplot(). install.packages(\"ggplot2\")")
    df <- as.data.frame(object)
    band_finite <- all(is.finite(df$lower)) && all(is.finite(df$upper))

    p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$time))
    if (band_finite)
      p <- p + ggplot2::geom_ribbon(
        ggplot2::aes(ymin = .data$lower, ymax = .data$upper),
        fill = "grey80", alpha = 0.5)
    p <- p +
      ggplot2::geom_line(ggplot2::aes(y = .data$treated),
                         color = "black", linewidth = 0.8) +
      ggplot2::geom_line(ggplot2::aes(y = .data$synthetic),
                         color = "black", linetype = "dashed",
                         linewidth = 0.8) +
      ggplot2::geom_vline(xintercept = object$treatment_time,
                          linetype = "dotted") +
      ggplot2::labs(x = "Time", y = "Y",
                    title = sprintf("Synthetic control (%s, %.0f%% band)",
                                    object$method, 100 * (1 - object$alpha))) +
      ggplot2::theme_minimal()
    p
  }

autoplot.synth_placebos <-
function(object, mspe_threshold = NULL, ...)
  {
    if (!requireNamespace("ggplot2", quietly = TRUE))
      stop("ggplot2 is required for autoplot(). install.packages(\"ggplot2\")")
    df <- as.data.frame(object)
    if (!is.null(mspe_threshold)) {
      keep_donors <- vapply(seq_along(object$placebos), function(i) {
        f <- object$placebos[[i]]
        !isTRUE(f$failed) &&
          !is.na(f$pre_mspe) &&
          f$pre_mspe <= mspe_threshold * object$treated$pre_mspe
      }, logical(1))
      keep_names <- c("(treated)", object$donor_names[keep_donors])
      df <- df[df$donor %in% keep_names, , drop = FALSE]
    }

    p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$time, y = .data$gap,
                                          group = .data$donor,
                                          color = .data$is_treated,
                                          linewidth = .data$is_treated)) +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed",
                          color = "grey60") +
      ggplot2::geom_vline(xintercept = object$treatment_time,
                          linetype = "dotted") +
      ggplot2::geom_line() +
      ggplot2::scale_color_manual(values = c(`FALSE` = "grey60",
                                              `TRUE`  = "black"),
                                  guide = "none") +
      ggplot2::scale_linewidth_manual(values = c(`FALSE` = 0.4,
                                                  `TRUE`  = 1.0),
                                      guide = "none") +
      ggplot2::labs(x = "Time", y = "Gap (treated - synthetic)",
                    title = "Placebo gaps") +
      ggplot2::theme_minimal()
    p
  }

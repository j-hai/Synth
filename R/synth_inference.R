synth_inference <-
function(synth.res = NULL,
         dataprep.res = NULL,
         method = c("conformal", "parametric"),
         alpha = 0.05,
         treatment_time = NULL)
  {
    method <- match.arg(method)

    # routine checks
    if(is.null(synth.res) || is.list(synth.res) == FALSE || is.null(synth.res$solution.w))
     {stop("\n synth.res does not look like a synth() output: missing solution.w \n")}
    if(is.null(dataprep.res) || is.list(dataprep.res) == FALSE || is.null(dataprep.res$tag))
     {stop("\n dataprep.res does not look like a dataprep() output: missing tag \n")}
    if(is.null(dataprep.res$Y1plot) || is.null(dataprep.res$Y0plot))
     {stop("\n dataprep.res missing Y1plot or Y0plot \n")}
    if(sum(is.na(dataprep.res$Y1plot)) > 0)
     {stop("\n You have missing Y data for the treated \n")}
    if(sum(is.na(dataprep.res$Y0plot)) > 0)
     {stop("\n You have missing Y data for the controls \n")}
    if(is.numeric(alpha) == FALSE || length(alpha) != 1 || alpha <= 0 || alpha >= 1)
     {stop("\n alpha must be a single number in (0, 1) \n")}

    base <- .synth_inference_base(synth.res, dataprep.res, treatment_time)
    if (length(base$pre_idx) < 2)
     {stop("\n Need at least 2 pre-treatment periods to compute a prediction band \n")}

    if (method == "conformal")
      out <- .synth_inference_conformal(base, alpha)
    else
      out <- .synth_inference_parametric(base, alpha)

    out
  }

.synth_inference_base <-
function(synth.res, dataprep.res, treatment_time = NULL)
  {
    p <- .period_indices(dataprep.res, treatment_time)

    treated   <- as.numeric(dataprep.res$Y1plot)
    synthetic <- as.numeric(dataprep.res$Y0plot %*% synth.res$solution.w)
    effect    <- treated - synthetic

    s <- .mspe_summary(effect, p$pre_idx, p$post_idx)

    list(
      time           = p$time_plot,
      pre_idx        = p$pre_idx,
      post_idx       = p$post_idx,
      treatment_time = p$treatment_time,
      treated        = treated,
      synthetic      = synthetic,
      effect         = effect,
      pre_mspe       = s$pre_mspe,
      post_mspe      = s$post_mspe,
      mspe_ratio     = s$mspe_ratio
    )
  }

# Split-conformal (Chernozhukov, Wuthrich, Zhu 2021) with the
# finite-sample (n+1) rank correction. The half-width is the order
# statistic at rank k = ceiling((n + 1) * (1 - alpha)) of the absolute
# pre-period residuals; this is the rank that delivers exact (1-alpha)
# coverage under exchangeability. When k > n the requested level is
# infeasible at this sample size and the function returns Inf.
.synth_inference_conformal <-
function(base, alpha)
  {
    r <- sort(abs(base$effect[base$pre_idx]))
    n <- length(r)
    k <- ceiling((n + 1) * (1 - alpha))
    if (k > n) {
      warning(sprintf(
        "Pre-period sample size n = %d is too small for finite-sample (1 - alpha) coverage at alpha = %g; conformal_q is Inf and the band is uninformative. Need n >= ceiling(1/alpha) - 1 = %d.",
        n, alpha, ceiling(1 / alpha) - 1))
      q <- Inf
    } else {
      q <- r[k]
    }
    intervals <- cbind(lower = base$synthetic - q,
                       upper = base$synthetic + q)
    out <- c(list(method = "conformal", alpha = alpha),
             base,
             list(intervals = intervals, conformal_q = q))
    class(out) <- c("synth_conformal", "synth_inference")
    out
  }

# Gaussian-residual prediction interval. Half-width is qnorm(1 - alpha/2)
# times the pre-period residual standard deviation.
.synth_inference_parametric <-
function(base, alpha)
  {
    sigma <- stats::sd(base$effect[base$pre_idx])
    h <- stats::qnorm(1 - alpha / 2) * sigma
    intervals <- cbind(lower = base$synthetic - h,
                       upper = base$synthetic + h)
    out <- c(list(method = "parametric", alpha = alpha),
             base,
             list(intervals = intervals, sigma_pre = sigma))
    class(out) <- c("synth_parametric", "synth_inference")
    out
  }

print.synth_inference <-
function(x, ...)
  {
    label <- switch(x$method,
                    conformal  = "split-conformal",
                    parametric = "parametric (Gaussian residuals)",
                    x$method)
    cat("Synthetic control inference (", label, ")\n", sep = "")
    cat("Pre-treatment periods (SSR window): ", length(x$pre_idx), "\n", sep = "")
    cat("Post-treatment periods (>= ", x$treatment_time, "): ",
        length(x$post_idx), "\n", sep = "")
    n.unclassified <- length(x$time) - length(x$pre_idx) - length(x$post_idx)
    if (n.unclassified > 0)
      cat("Pre-treatment periods outside SSR window: ", n.unclassified,
          " (excluded from MSPE summaries)\n", sep = "")

    if (x$method == "conformal") {
      if (is.infinite(x$conformal_q))
        cat(sprintf("alpha = %.3f, conformal q = Inf (sample too small)\n", x$alpha))
      else
        cat(sprintf("alpha = %.3f, conformal q = %.4f\n", x$alpha, x$conformal_q))
    } else if (x$method == "parametric") {
      cat(sprintf("alpha = %.3f, sigma_pre = %.4f, half-width = %.4f\n",
                  x$alpha, x$sigma_pre,
                  stats::qnorm(1 - x$alpha / 2) * x$sigma_pre))
    }

    cat(sprintf("Pre-period MSPE  = %.4f\n", x$pre_mspe))
    if (!is.na(x$post_mspe)) {
      cat(sprintf("Post-period MSPE = %.4f\n", x$post_mspe))
      cat(sprintf("Post/Pre MSPE ratio = %.4f\n", x$mspe_ratio))
      n.outside <- sum(x$treated[x$post_idx] < x$intervals[x$post_idx, "lower"] |
                       x$treated[x$post_idx] > x$intervals[x$post_idx, "upper"])
      cat(sprintf("Post-period points outside (1-alpha) band: %d / %d\n",
                  n.outside, length(x$post_idx)))
    }

    cat("\nNote: validity assumes pre-period residuals are ")
    if (x$method == "conformal")
      cat("exchangeable.\n")
    else
      cat("i.i.d. Gaussian.\n")
    cat("With autocorrelated outcomes the nominal coverage is approximate.\n")
    cat("See ?synth_inference, the SCtools package for placebo-based\n")
    cat("inference, and the scpi package for methods that decompose\n")
    cat("in-sample and out-of-sample uncertainty.\n")
    invisible(x)
  }

plot.synth_inference <-
function(x,
         Ylab = "Y",
         Xlab = "Time",
         Main = NA,
         Ylim = NA,
         Legend = c("Treated", "Synthetic", paste0(100 * (1 - x$alpha), "% band")),
         Legend.position = "topright",
         tr.intake = NA,
         band.col = grDevices::rgb(0, 0, 0, 0.15),
         ...)
  {
    if (is.na(tr.intake)) {
      if (!is.null(x$treatment_time))
        tr.intake <- x$treatment_time
      else if (length(x$post_idx) > 0)
        tr.intake <- x$time[min(x$post_idx)]
    }

    band_finite <- all(is.finite(x$intervals))
    if (sum(is.na(Ylim)) > 0) {
      ys <- if (band_finite) c(x$intervals[, "upper"], x$intervals[, "lower"], x$treated)
            else c(x$treated, x$synthetic)
      Y.max <- max(ys)
      Y.min <- min(ys)
      Y.pad <- 0.3 * (Y.max - Y.min)
      if (Y.pad == 0) Y.pad <- 0.3 * max(abs(c(Y.min, Y.max)), 1)
      Ylim <- c(Y.min - Y.pad, Y.max + Y.pad)
    }

    plot(x$time, x$treated,
         t = "n",
         main = Main, ylab = Ylab, xlab = Xlab,
         xaxs = "i", yaxs = "i", ylim = Ylim)

    if (band_finite) {
      graphics::polygon(
        x = c(x$time, rev(x$time)),
        y = c(x$intervals[, "lower"], rev(x$intervals[, "upper"])),
        col = band.col, border = NA
      )
    }

    lines(x$time, x$treated,   col = "black", lwd = 2)
    lines(x$time, x$synthetic, col = "black", lwd = 2, lty = "dashed")

    abline(v = tr.intake, lty = 3, col = "black", lwd = 2)

    if (sum(is.na(Legend)) == 0) {
      legend(Legend.position, legend = Legend,
             lty = c(1, 2, NA), pch = c(NA, NA, 15),
             col = c("black", "black", band.col),
             lwd = c(2, 2, NA), cex = 6/7)
    }

    invisible(x)
  }

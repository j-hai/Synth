plot.synth_sensitivity <- function(x,
                                   type = c("specification_curve", "paths",
                                            "validation"),
                                   ...) {
  type <- match.arg(type)
  if (type == "specification_curve") {
    tab <- x$estimates[order(x$estimates$att, na.last = TRUE), ]
    margins <- graphics::par("mar")
    margins[1] <- max(
      margins[1],
      max(graphics::strwidth(tab$spec_id, units = "inches")) /
        graphics::par("csi") + 3
    )
    old_par <- graphics::par(mar = margins)
    on.exit(graphics::par(old_par), add = TRUE)
    finite <- is.finite(tab$att)
    ylim <- if (any(finite)) range(c(0, tab$att[finite])) else c(-1, 1)
    if (diff(ylim) == 0) ylim <- ylim + c(-1, 1)
    graphics::plot(seq_len(nrow(tab)), rep(NA_real_, nrow(tab)),
      ylim = ylim, xaxt = "n", xlab = "",
      ylab = "ATT", ...
    )
    graphics::axis(1, at = seq_len(nrow(tab)), labels = tab$spec_id, las = 2)
    graphics::mtext("Specification", side = 1, line = margins[1] - 1)
    graphics::abline(h = 0, col = "gray")
    graphics::points(which(finite), tab$att[finite],
      pch = ifelse(tab$status[finite] == "warning", 4, 16)
    )
    if (any(!finite)) {
      graphics::text(
        which(!finite), graphics::par("usr")[3], "failed",
        pos = 3, srt = 90
      )
    }
    graphics::mtext(
      "x: fit with warnings; failed: no estimate",
      side = 3, cex = .8
    )
  } else if (type == "paths") {
    if (!nrow(x$paths)) {
      graphics::plot.new()
      graphics::text(.5, .5, paste(nrow(x$estimates), "attempts; all failed"))
    } else {
      paths <- split(x$paths, x$paths$spec_id)
      first <- paths[[1]]
      graphics::plot(first$time, first$observed,
        type = "l", lwd = 2,
        ylim = range(c(x$paths$observed, x$paths$synthetic)),
        xlab = "Time", ylab = "Outcome", ...
      )
      for (i in seq_along(paths)) {
        graphics::lines(
          paths[[i]]$time, paths[[i]]$synthetic,
          col = i + 1, lty = 2
        )
      }
      graphics::abline(v = x$metadata$treatment_time, lty = 3)
      graphics::legend("topleft",
        legend = c("Observed", names(paths)),
        col = seq_len(length(paths) + 1),
        lty = c(1, rep(2, length(paths))), cex = .8
      )
      graphics::mtext(
        paste(nrow(x$failures), "failed attempts (see failures)"),
        side = 3, cex = .8
      )
    }
  } else {
    .plot_sensitivity_validation(x, ...)
  }
  invisible(x)
}

.plot_sensitivity_validation <- function(x, ...) {
  if (!length(x$metadata$validation_windows)) {
    stop("Declare validation_windows before fitting")
  }
  tab <- x$estimates
  finite <- is.finite(tab$att) & is.finite(tab$validation_rmse)
  limit <- x$metadata$validation_max_rmse
  graphics::plot(tab$validation_rmse[finite], tab$att[finite],
    xlim = range(c(0, limit, tab$validation_rmse[finite])),
    ylim = range(c(0, tab$att[finite])),
    xlab = "Pre-treatment validation RMSE", ylab = "ATT",
    pch = ifelse(
      tab$status[finite] == "warning" |
        tab$validation_status[finite] == "warning", 4, 16
    ), ...
  )
  if (any(finite)) {
    graphics::text(tab$validation_rmse[finite], tab$att[finite],
      labels = tab$spec_id[finite], pos = rep(c(3, 1), length.out = sum(finite))
    )
  }
  graphics::abline(h = 0, col = "gray")
  if (!is.null(limit)) graphics::abline(v = limit, col = "gray", lty = 2)
  if (any(!finite)) {
    graphics::mtext(paste(
      "ATT or validation unavailable:",
      paste(tab$spec_id[!finite], collapse = ", ")
    ), side = 3, cex = .8)
  }
  invisible(x)
}

# as.data.frame() methods for the inference and placebo S3 classes.
# Long-format data frames with `period` factor and `is_treated` flag,
# suitable for piping into ggplot2 or fwrite().

as.data.frame.synth_inference <-
function(x, ...)
  {
    period <- rep("unclassified", length(x$time))
    period[x$pre_idx]  <- "pre"
    period[x$post_idx] <- "post"
    out <- data.frame(
      time      = x$time,
      period    = factor(period, levels = c("pre", "post", "unclassified")),
      treated   = x$treated,
      synthetic = x$synthetic,
      effect    = x$effect,
      lower     = x$intervals[, "lower"],
      upper     = x$intervals[, "upper"],
      stringsAsFactors = FALSE
    )
    attr(out, "treatment_time") <- x$treatment_time
    attr(out, "method")         <- x$method
    attr(out, "alpha")          <- x$alpha
    out
  }

as.data.frame.synth_placebos <-
function(x, ...)
  {
    keep <- which(!x$failed)
    if (length(keep) == 0)
      return(data.frame(time = numeric(0), donor = character(0),
                        gap = numeric(0), is_treated = logical(0),
                        stringsAsFactors = FALSE))

    rows <- lapply(seq_along(keep), function(j) {
      i <- keep[j]
      data.frame(
        time       = x$time,
        donor      = x$donor_names[i],
        gap        = x$placebos[[i]]$gap,
        is_treated = FALSE,
        stringsAsFactors = FALSE
      )
    })
    treated.row <- data.frame(
      time       = x$time,
      donor      = "(treated)",
      gap        = x$treated$gap,
      is_treated = TRUE,
      stringsAsFactors = FALSE
    )
    out <- do.call(rbind, c(list(treated.row), rows))
    attr(out, "treatment_time") <- x$treatment_time
    out
  }

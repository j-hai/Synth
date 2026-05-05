generate_placebos <-
function(synth.res = NULL,
         dataprep.res = NULL,
         Sigf.ipop = 5,
         Margin.ipop = 0.0005,
         Bound.ipop = 10,
         optimxmethod = c("Nelder-Mead", "BFGS"),
         genoud = FALSE,
         custom.v = NULL,
         verbose = FALSE,
         parallel = FALSE,
         n_cores = NULL,
         quadopt = "ipop",
         quadopt_inner = NULL,
         quadopt_outer = NULL,
         cvxr_pars = list(),
         cvxr_pars_inner = NULL,
         cvxr_pars_outer = NULL,
         torch_pars = list(),
         torch_pars_inner = NULL,
         torch_pars_outer = NULL,
         treatment_time = NULL,
         keep_fits = FALSE)
  {
    # routine checks
    if(is.null(synth.res) || is.list(synth.res) == FALSE || is.null(synth.res$solution.w))
     {stop("\n synth.res does not look like a synth() output: missing solution.w \n")}
    if(is.null(dataprep.res) || is.list(dataprep.res) == FALSE || is.null(dataprep.res$tag))
     {stop("\n dataprep.res does not look like a dataprep() output: missing tag \n")}
    if(is.null(dataprep.res$X1) || is.null(dataprep.res$X0) ||
       is.null(dataprep.res$Z1) || is.null(dataprep.res$Z0) ||
       is.null(dataprep.res$Y1plot) || is.null(dataprep.res$Y0plot))
     {stop("\n dataprep.res missing one of X1/X0/Z1/Z0/Y1plot/Y0plot \n")}

    n.donors <- ncol(dataprep.res$X0)
    if (n.donors < 2)
     {stop("\n Need at least 2 donors in the original control pool to run placebos \n")}

    p <- .period_indices(dataprep.res, treatment_time)
    time.plot      <- p$time_plot
    pre.idx        <- p$pre_idx
    post.idx       <- p$post_idx
    treatment_time <- p$treatment_time

    # colnames(X0) is set to controls.identifier by dataprep(); upgrade
    # to human-readable names from names.and.numbers when possible.
    donor.ids <- colnames(dataprep.res$X0)
    nn <- dataprep.res$names.and.numbers
    if (!is.null(nn) && ncol(nn) >= 2 && !is.null(donor.ids)) {
      matched <- as.character(nn[match(as.character(donor.ids),
                                       as.character(nn[, 2])), 1])
      donor.names <- ifelse(is.na(matched) | matched == "",
                            as.character(donor.ids), matched)
    } else if (!is.null(donor.ids)) {
      donor.names <- as.character(donor.ids)
    } else {
      donor.names <- paste0("donor_", seq_len(n.donors))
    }
    if (length(donor.names) != n.donors)
      donor.names <- paste0("donor_", seq_len(n.donors))

    # Real-treated summary (computed once, reused as the reference point)
    real.treated   <- as.numeric(dataprep.res$Y1plot)
    real.synthetic <- as.numeric(dataprep.res$Y0plot %*% synth.res$solution.w)
    real.gap       <- real.treated - real.synthetic
    real.summary   <- .mspe_summary(real.gap, pre.idx, post.idx)
    treated.summary <- c(list(gap = real.gap), real.summary)

    fit_one <- function(i) {
      swapped <- .swap_donor_into_treated(dataprep.res, i)
      err.msg <- NA_character_
      fit <- tryCatch(
        synth(data.prep.obj = swapped,
              custom.v      = custom.v,
              optimxmethod  = optimxmethod,
              genoud        = genoud,
              quadopt       = quadopt,
              quadopt_inner = quadopt_inner,
              quadopt_outer = quadopt_outer,
              cvxr_pars        = cvxr_pars,
              cvxr_pars_inner  = cvxr_pars_inner,
              cvxr_pars_outer  = cvxr_pars_outer,
              torch_pars       = torch_pars,
              torch_pars_inner = torch_pars_inner,
              torch_pars_outer = torch_pars_outer,
              Margin.ipop   = Margin.ipop,
              Sigf.ipop     = Sigf.ipop,
              Bound.ipop    = Bound.ipop,
              verbose       = verbose),
        error = function(e) { err.msg <<- conditionMessage(e); NULL }
      )
      if (is.null(fit)) {
        return(list(gap = rep(NA_real_, length(time.plot)),
                    pre_mspe = NA_real_, post_mspe = NA_real_,
                    mspe_ratio = NA_real_,
                    failed = TRUE,
                    error_message = err.msg,
                    fit = NULL))
      }
      treated.i   <- as.numeric(swapped$Y1plot)
      synthetic.i <- as.numeric(swapped$Y0plot %*% fit$solution.w)
      gap.i       <- treated.i - synthetic.i
      s.i <- suppressWarnings(.mspe_summary(gap.i, pre.idx, post.idx))
      out.i <- c(list(gap = gap.i), s.i,
                 list(failed = FALSE,
                      error_message = NA_character_,
                      fit = if (isTRUE(keep_fits)) fit else NULL))
      out.i
    }

    # Resolve the parallel mode. parallel can be:
    #   FALSE / "none"           -- serial
    #   TRUE / "auto"            -- multicore on unix-likes, snow on Windows
    #   "multicore"              -- forks via parallel::mclapply (errors on Windows)
    #   "snow"                   -- PSOCK cluster via parallel::parLapply
    par.mode <- .resolve_parallel_mode(parallel)
    if (par.mode != "none" && is.null(n_cores))
      n_cores <- max(1L, parallel::detectCores(logical = FALSE) - 1L)

    if (par.mode == "multicore") {
      placebo.fits <- parallel::mclapply(seq_len(n.donors), fit_one, mc.cores = n_cores)
    } else if (par.mode == "snow") {
      cl <- parallel::makePSOCKcluster(n_cores)
      on.exit(parallel::stopCluster(cl), add = TRUE)
      parallel::clusterEvalQ(cl, library(Synth))
      parallel::clusterExport(cl,
        varlist = c("dataprep.res", "fit_one", "pre.idx", "post.idx",
                    "time.plot", "Margin.ipop", "Sigf.ipop", "Bound.ipop",
                    "optimxmethod", "genoud", "custom.v", "verbose",
                    "quadopt", "quadopt_inner", "quadopt_outer",
                    "cvxr_pars", "cvxr_pars_inner", "cvxr_pars_outer",
                    "torch_pars", "torch_pars_inner", "torch_pars_outer",
                    "keep_fits"),
        envir = environment())
      placebo.fits <- parallel::parLapply(cl, seq_len(n.donors), fit_one)
    } else {
      # Serial: optionally print progress to stderr after each refit.
      if (isTRUE(verbose)) {
        placebo.fits <- vector("list", n.donors)
        for (i in seq_len(n.donors)) {
          placebo.fits[[i]] <- fit_one(i)
          msg <- sprintf("[Synth] placebo %d/%d (%s)%s\n",
                         i, n.donors, donor.names[i],
                         if (isTRUE(placebo.fits[[i]]$failed)) " FAILED" else "")
          message(msg, appendLF = FALSE)
        }
      } else {
        placebo.fits <- lapply(seq_len(n.donors), fit_one)
      }
    }
    names(placebo.fits) <- donor.names

    failed <- vapply(placebo.fits, function(f) isTRUE(f$failed), logical(1))

    out <- list(
      treated        = treated.summary,
      placebos       = placebo.fits,
      time           = time.plot,
      pre_idx        = pre.idx,
      post_idx       = post.idx,
      treatment_time = treatment_time,
      donor_names    = donor.names,
      failed         = failed
    )
    class(out) <- "synth_placebos"
    out
  }

# Internal: resolve user-supplied `parallel` argument (FALSE/TRUE/string)
# into one of "none" / "multicore" / "snow". Errors on multicore + Windows.
.resolve_parallel_mode <-
function(parallel)
  {
    if (isFALSE(parallel) || identical(parallel, "none"))
      return("none")
    is.win <- identical(.Platform$OS.type, "windows")
    if (isTRUE(parallel) || identical(parallel, "auto"))
      return(if (is.win) "snow" else "multicore")
    if (identical(parallel, "multicore")) {
      if (is.win)
        stop("\n parallel = \"multicore\" is not available on Windows; use parallel = \"snow\" or parallel = TRUE \n")
      return("multicore")
    }
    if (identical(parallel, "snow"))
      return("snow")
    stop(sprintf(
      "\n Unknown parallel = %s. Supported: FALSE/TRUE, \"none\", \"auto\", \"multicore\", \"snow\" \n",
      deparse(parallel)))
  }

# Internal: place donor `i` into the treated slot, with the original
# treated unit taking donor i's column in the control pool. Donor pool
# size is preserved.
.swap_donor_into_treated <-
function(d, i)
  {
    swapped <- d
    swapped$X1 <- d$X0[, i, drop = FALSE]
    swapped$X0 <- d$X0
    swapped$X0[, i] <- d$X1[, 1]

    swapped$Z1 <- d$Z0[, i, drop = FALSE]
    swapped$Z0 <- d$Z0
    swapped$Z0[, i] <- d$Z1[, 1]

    swapped$Y1plot <- d$Y0plot[, i, drop = FALSE]
    swapped$Y0plot <- d$Y0plot
    swapped$Y0plot[, i] <- d$Y1plot[, 1]

    swapped
  }

mspe_test <-
function(placebos)
  {
    if (!inherits(placebos, "synth_placebos"))
      stop("\n placebos must be the output of generate_placebos() \n")

    treated.ratio <- placebos$treated$mspe_ratio
    placebo.ratios <- vapply(placebos$placebos, function(f) f$mspe_ratio, numeric(1))
    valid <- !is.na(placebo.ratios)

    pvalue <- if (any(valid))
                mean(c(treated.ratio, placebo.ratios[valid]) >= treated.ratio)
              else NA_real_

    list(
      mspe_ratio_treated   = treated.ratio,
      mspe_ratios_placebos = placebo.ratios,
      pvalue               = pvalue,
      n_valid_placebos     = sum(valid)
    )
  }

mspe_plot <-
function(placebos,
         Main = "Post/Pre MSPE Ratio",
         Xlab = "MSPE ratio",
         Ylab = "")
  {
    if (!inherits(placebos, "synth_placebos"))
      stop("\n placebos must be the output of generate_placebos() \n")

    treated.ratio  <- placebos$treated$mspe_ratio
    placebo.ratios <- vapply(placebos$placebos, function(f) f$mspe_ratio, numeric(1))
    valid <- !is.na(placebo.ratios)

    ratios <- c(placebo.ratios[valid], treated.ratio)
    labels <- c(placebos$donor_names[valid], "TREATED")
    ord <- order(ratios)
    ratios <- ratios[ord]
    labels <- labels[ord]
    is.treated <- labels == "TREATED"

    plot(ratios, seq_along(ratios),
         pch = ifelse(is.treated, 19, 1),
         col = ifelse(is.treated, "black", "grey40"),
         cex = ifelse(is.treated, 1.2, 0.9),
         yaxt = "n", main = Main, xlab = Xlab, ylab = Ylab)
    graphics::axis(2, at = seq_along(ratios), labels = labels,
                   las = 1, cex.axis = 0.7)
    invisible(NULL)
  }

plot_placebos <-
function(placebos,
         mspe_threshold = NULL,
         Ylab = "Gap",
         Xlab = "Time",
         Main = "Placebo Gaps",
         Ylim = NA,
         tr.intake = NA,
         treated_col = "black",
         placebo_col = "grey60")
  {
    if (!inherits(placebos, "synth_placebos"))
      stop("\n placebos must be the output of generate_placebos() \n")

    pre.idx <- placebos$pre_idx
    post.idx <- placebos$post_idx
    if (is.na(tr.intake)) {
      if (!is.null(placebos$treatment_time))
        tr.intake <- placebos$treatment_time
      else if (length(post.idx) > 0)
        tr.intake <- placebos$time[min(post.idx)]
    }

    placebo.gaps <- do.call(rbind, lapply(placebos$placebos, function(f) f$gap))
    if (!is.null(mspe_threshold)) {
      ratios <- vapply(placebos$placebos, function(f) f$pre_mspe, numeric(1))
      keep <- !is.na(ratios) & ratios <= mspe_threshold * placebos$treated$pre_mspe
      placebo.gaps <- placebo.gaps[keep, , drop = FALSE]
    }

    treated.gap <- placebos$treated$gap

    if (sum(is.na(Ylim)) > 0) {
      all.gaps <- c(treated.gap, as.numeric(placebo.gaps))
      all.gaps <- all.gaps[is.finite(all.gaps)]
      Y.max <- max(all.gaps)
      Y.min <- min(all.gaps)
      Y.pad <- 0.3 * (Y.max - Y.min)
      if (Y.pad == 0) Y.pad <- 0.3 * max(abs(c(Y.min, Y.max)), 1)
      Ylim <- c(Y.min - Y.pad, Y.max + Y.pad)
    }

    plot(placebos$time, treated.gap,
         t = "n",
         main = Main, ylab = Ylab, xlab = Xlab,
         xaxs = "i", yaxs = "i", ylim = Ylim)

    for (k in seq_len(nrow(placebo.gaps))) {
      g <- placebo.gaps[k, ]
      if (any(is.na(g))) next
      lines(placebos$time, g, col = placebo_col, lwd = 1)
    }
    lines(placebos$time, treated.gap, col = treated_col, lwd = 2)

    abline(h = 0, col = "black", lty = "dashed", lwd = 1)
    abline(v = tr.intake, lty = 3, col = "black", lwd = 2)

    invisible(NULL)
  }

print.synth_placebos <-
function(x, ...)
  {
    cat("Synth placebos\n")
    cat("Donors:           ", length(x$donor_names), "\n", sep = "")
    cat("Successful refits:", sum(!x$failed), "\n", sep = "")
    cat("Failed refits:    ", sum(x$failed), "\n", sep = "")
    if (sum(x$failed) > 0) {
      msgs <- vapply(x$placebos[x$failed],
                     function(f) f$error_message %||% NA_character_,
                     character(1))
      msgs <- msgs[!is.na(msgs)]
      if (length(msgs) > 0) {
        tab <- sort(table(msgs), decreasing = TRUE)
        top <- names(tab)[1]
        cat("  Most common error: ", top,
            sprintf(" (hit %d/%d failed)", as.integer(tab[1]), sum(x$failed)),
            "\n", sep = "")
      }
    }
    cat("Pre-treatment periods : ", length(x$pre_idx), "\n", sep = "")
    cat("Post-treatment periods: ", length(x$post_idx), "\n", sep = "")
    cat(sprintf("Treated post/pre MSPE ratio: %.4f\n", x$treated$mspe_ratio))
    test <- mspe_test(x)
    cat(sprintf("One-sided placebo p-value:   %.4f  (n_valid = %d)\n",
                test$pvalue, test$n_valid_placebos))
    invisible(x)
  }

plot.synth_placebos <-
function(x, ...) plot_placebos(x, ...)

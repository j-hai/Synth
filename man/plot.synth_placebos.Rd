\name{plot.synth_placebos}
\alias{plot.synth_placebos}
\title{Overlay placebo gap series with the treated gap}
\description{
Overlay plot of placebo gap series (in grey) with the treated gap highlighted in black. Operates on the output of \code{\link{synth_placebos}}.
}
\usage{
\method{plot}{synth_placebos}(x,
     mspe_threshold = NULL,
     Ylab = "Gap",
     Xlab = "Time",
     Main = "Placebo Gaps",
     Ylim = NA,
     tr.intake = NA,
     treated_col = "black",
     placebo_col = "grey60",
     ...)
}
\arguments{
  \item{x}{Output of \code{\link{synth_placebos}}.}
  \item{mspe_threshold}{Optional scalar; if supplied, placebos whose pre-period MSPE exceeds \code{mspe_threshold * treated_pre_mspe} are dropped from the plot. The standard idiom is \code{mspe_threshold = 5} (drop placebos whose own pre-period MSPE is more than five times the treated unit's).}
  \item{Ylab}{Y axis label.}
  \item{Xlab}{X axis label.}
  \item{Main}{Optional main title.}
  \item{Ylim}{Optional Ylim. If \code{NA}, padded automatically.}
  \item{tr.intake}{Optional scalar locating the treatment date with a vertical dotted line. If \code{NA}, defaults to \code{x$treatment_time}, the first post-treatment period.}
  \item{treated_col}{Color for the treated gap line.}
  \item{placebo_col}{Color for placebo gap lines.}
  \item{\dots}{Not used; a warning is given if anything is passed. Base graphics arguments such as \code{main}, \code{xlab} or \code{ylim} are not passed on: use \code{Main}, \code{Xlab}, \code{Ylab} and \code{Ylim}.}
}
\value{Invisibly returns \code{NULL}.}
\references{
Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic Control Methods for Comparative Case Studies. \emph{Journal of the American Statistical Association} 105 (490) 493--505.
}
\seealso{\code{\link{synth_placebos}}, \code{\link{synth_mspe_test}}, \code{\link{synth_mspe_plot}}.}

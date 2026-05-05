\name{plot_placebos}
\alias{plot_placebos}
\title{Overlay placebo gap series with the treated gap}
\description{
Overlay plot of placebo gap series (in grey) with the treated gap highlighted in black. Operates on the output of \code{\link{generate_placebos}}.
}
\usage{
plot_placebos(placebos,
              mspe_threshold = NULL,
              Ylab = "Gap",
              Xlab = "Time",
              Main = "Placebo Gaps",
              Ylim = NA,
              tr.intake = NA,
              treated_col = "black",
              placebo_col = "grey60")
}
\arguments{
  \item{placebos}{Output of \code{\link{generate_placebos}}.}
  \item{mspe_threshold}{Optional scalar; if supplied, placebos whose pre-period MSPE exceeds \code{mspe_threshold * treated_pre_mspe} are dropped from the plot. The standard idiom is \code{mspe_threshold = 5} (drop placebos that pre-fit the treated unit's outcome much worse than the treated unit's own synthetic).}
  \item{Ylab}{Y axis label.}
  \item{Xlab}{X axis label.}
  \item{Main}{Optional main title.}
  \item{Ylim}{Optional Ylim. If \code{NA}, padded automatically.}
  \item{tr.intake}{Optional scalar locating the treatment date with a vertical dashed line. If \code{NA}, defaults to the first post-treatment period in \code{placebos$time}.}
  \item{treated_col}{Color for the treated gap line.}
  \item{placebo_col}{Color for placebo gap lines.}
}
\value{Invisibly returns \code{NULL}.}
\references{
Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic Control Methods for Comparative Case Studies. \emph{Journal of the American Statistical Association} 105 (490) 493--505.
}
\seealso{\code{\link{generate_placebos}}, \code{\link{mspe_test}}, \code{\link{mspe_plot}}.}

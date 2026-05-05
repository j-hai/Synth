\name{plot.synth_inference}
\alias{plot.synth_inference}
\title{Plot a synthetic control prediction band}
\description{
Plots the treated and synthetic series with a shaded prediction band on the same axes. The band comes from \code{\link{synth_inference}}.
}
\usage{
\method{plot}{synth_inference}(x,
     Ylab = "Y",
     Xlab = "Time",
     Main = NA,
     Ylim = NA,
     Legend = c("Treated", "Synthetic", paste0(100 * (1 - x$alpha), "\% band")),
     Legend.position = "topright",
     tr.intake = NA,
     band.col = grDevices::rgb(0, 0, 0, 0.15),
     ...)
}
\arguments{
  \item{x}{Object of class \code{synth_inference}.}
  \item{Ylab}{Y axis label.}
  \item{Xlab}{X axis label.}
  \item{Main}{Optional main title.}
  \item{Ylim}{Optional Ylim. If \code{NA}, padded automatically.}
  \item{Legend}{Legend entries. Set to \code{NA} to suppress.}
  \item{Legend.position}{Legend position; passed to \code{\link[graphics]{legend}}.}
  \item{tr.intake}{Optional scalar locating the treatment date with a vertical dashed line. If \code{NA}, defaults to the first post-treatment period in \code{x$time}.}
  \item{band.col}{Fill color for the prediction band; default a translucent grey.}
  \item{\dots}{Currently unused.}
}
\value{Invisibly returns \code{x}.}
\seealso{\code{\link{synth_inference}}}

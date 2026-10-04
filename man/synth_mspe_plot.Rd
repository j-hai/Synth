\name{synth_mspe_plot}
\alias{synth_mspe_plot}
\title{Plot of placebo post/pre MSPE ratios}
\description{
Plots the distribution of post/pre MSPE ratios across placebos with the treated unit highlighted. Operates on the output of \code{\link{synth_placebos}}.
}
\usage{
synth_mspe_plot(placebos,
                Main = "Post/Pre MSPE Ratio",
                Xlab = "MSPE ratio",
                Ylab = "")
}
\arguments{
  \item{placebos}{Output of \code{\link{synth_placebos}}.}
  \item{Main}{Optional main title.}
  \item{Xlab}{X axis label.}
  \item{Ylab}{Y axis label.}
}
\value{Invisibly returns \code{NULL}.}
\seealso{\code{\link{synth_placebos}}, \code{\link{synth_mspe_test}}, \code{\link{plot.synth_placebos}}.}

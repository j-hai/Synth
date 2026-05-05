\name{synth_inference}
\alias{synth_inference}
\alias{print.synth_inference}
\title{Prediction intervals for synthetic control counterfactuals}
\description{
Computes a prediction band around the synthetic counterfactual produced by \code{\link{synth}} and \code{\link{dataprep}}. Two methods are supported: split-conformal intervals (the default) and parametric Gaussian intervals.
}
\usage{
synth_inference(synth.res = NULL,
                dataprep.res = NULL,
                method = c("conformal", "parametric"),
                alpha = 0.05,
                treatment_time = NULL)
}
\arguments{
  \item{synth.res}{Output list from \code{\link{synth}}.}
  \item{dataprep.res}{Output list from \code{\link{dataprep}}.}
  \item{method}{One of \code{"conformal"} (default) or \code{"parametric"}. See Details.}
  \item{alpha}{Miscoverage level. The band targets nominal \eqn{(1-\alpha)} coverage. Default 0.05.}
  \item{treatment_time}{Optional first post-treatment period (a value of \code{dataprep.res$tag$time.plot}). If \code{NULL} (default), the first post-treatment period is taken to be \code{max(time.optimize.ssr) + 1}. The post window is \code{time.plot >= treatment_time}; pre-treatment plot years \emph{before} the SSR optimization window (e.g.\ 1955--1959 in a typical Basque setup with \code{time.optimize.ssr = 1960:1969}) are pre-treatment and are excluded from post-period MSPE summaries.}
}
\details{
With \code{method = "conformal"}, the half-width of the band is the order statistic at rank \eqn{k = \lceil (n + 1)(1 - \alpha) \rceil} of the absolute pre-treatment residuals \eqn{|\hat{Y}_{1,t} - \hat{Y}_{0,t} \hat{w}|} (Chernozhukov, Wuthrich, and Zhu 2021). The \eqn{(n+1)} adjustment delivers exact \eqn{(1-\alpha)} finite-sample coverage under exchangeability. When \eqn{k > n} the requested level is infeasible at this calibration sample size, the function emits a warning, and \code{conformal_q} is \code{Inf}.

With \code{method = "parametric"}, the half-width is \code{qnorm(1 - alpha/2)} times the standard deviation of pre-period residuals. This assumes residuals are i.i.d. Gaussian.

Both methods produce constant-width bands. They do \emph{not} separately quantify uncertainty about the synthetic weights \eqn{\hat{w}} or decompose in-sample versus out-of-sample uncertainty. Users who need period-varying intervals or that decomposition should see the \pkg{scpi} package.

Validity in both methods is approximate when outcomes are autocorrelated.
}
\value{
An object of S3 class \code{c("synth_<method>", "synth_inference")}, a list with components:
  \item{method}{The method used (echoed).}
  \item{alpha}{Miscoverage level (echoed).}
  \item{time}{The full plot horizon (\code{dataprep.res$tag$time.plot}).}
  \item{pre_idx, post_idx}{Integer indices into \code{time} for pre- and post-treatment periods.}
  \item{treated, synthetic}{Numeric vectors over \code{time}: observed treated outcome and synthetic counterfactual.}
  \item{effect}{\code{treated - synthetic}.}
  \item{intervals}{Numeric matrix with \code{lower} and \code{upper} columns for each period in \code{time}.}
  \item{conformal_q}{(conformal only) The \eqn{(1-\alpha)}-quantile of \eqn{|\mathrm{gap}_{\mathrm{pre}}|}.}
  \item{sigma_pre}{(parametric only) Standard deviation of pre-period residuals.}
  \item{pre_mspe, post_mspe, mspe_ratio}{Mean squared prediction error in the pre- and post-treatment periods, and their ratio.}
}
\references{
Chernozhukov, V., Wuthrich, K., and Zhu, Y. (2021). An exact and robust conformal inference method for counterfactual and synthetic controls. \emph{Journal of the American Statistical Association} 116 (536) 1849--1864.

Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic Control Methods for Comparative Case Studies. \emph{Journal of the American Statistical Association} 105 (490) 493--505.

Cattaneo, M. D., Feng, Y., Palomba, F., and Titiunik, R. (2025). Uncertainty quantification in synthetic controls with staggered treatment adoption. \emph{Review of Economics and Statistics}.
}
\author{Jens Hainmueller and Alexis Diamond}
\seealso{
\code{\link{synth}}, \code{\link{dataprep}}, \code{\link{plot.synth_inference}}, \code{\link{generate_placebos}}.
The \pkg{SCtools} package provides additional placebo-based inference; the \pkg{scpi} package provides period-varying CFPT prediction intervals that decompose in-sample and out-of-sample uncertainty.
}
\examples{
\dontrun{
data(synth.data)
d <- dataprep(
  foo = synth.data,
  predictors = c("X1", "X2", "X3"),
  predictors.op = "mean",
  dependent = "Y",
  unit.variable = "unit.num",
  time.variable = "year",
  treatment.identifier = 7,
  controls.identifier = c(29, 2, 13, 17, 32, 38),
  time.predictors.prior = 1984:1989,
  time.optimize.ssr = 1984:1990,
  unit.names.variable = "name",
  time.plot = 1984:1996
)
fit <- synth(d)
inf <- synth_inference(fit, d, method = "conformal", alpha = 0.10)
print(inf)
plot(inf)
}
}

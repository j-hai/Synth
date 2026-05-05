\name{generate_placebos}
\alias{generate_placebos}
\alias{print.synth_placebos}
\alias{plot.synth_placebos}
\title{In-space placebo refits for synthetic control inference}
\description{
For each donor in the original control pool, swap that donor into the treated slot, refit \code{\link{synth}}, and record the resulting gap series. The returned object feeds \code{\link{mspe_test}}, \code{\link{mspe_plot}}, and \code{\link{plot_placebos}}.
}
\usage{
generate_placebos(synth.res = NULL,
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
}
\arguments{
  \item{synth.res}{Output list from \code{\link{synth}} for the real treated unit. Used only for the reference summary; placebos are refit from \code{dataprep.res}.}
  \item{dataprep.res}{Output list from \code{\link{dataprep}}.}
  \item{Sigf.ipop, Margin.ipop, Bound.ipop, optimxmethod, custom.v, verbose}{Passed through to each \code{\link{synth}} placebo refit. Match these to the configuration that produced \code{synth.res} for like-for-like inference.}
  \item{parallel}{Parallelization mode. One of \code{FALSE} / \code{"none"} (serial; default), \code{TRUE} / \code{"auto"} (forks via \code{\link[parallel]{mclapply}} on unix-likes; PSOCK cluster on Windows), \code{"multicore"} (forces \code{mclapply}; errors on Windows), or \code{"snow"} (forces a PSOCK cluster via \code{\link[parallel]{makePSOCKcluster}} + \code{\link[parallel]{parLapply}}; works on all platforms).}
  \item{n_cores}{Number of cores when \code{parallel = TRUE}. Defaults to one less than the number of physical cores.}
  \item{quadopt, quadopt_inner, quadopt_outer, cvxr_pars, cvxr_pars_inner, cvxr_pars_outer, torch_pars, torch_pars_inner, torch_pars_outer}{Forwarded to each placebo refit's \code{\link{synth}} call. Match these to the configuration that produced \code{synth.res} for like-for-like inference. See \code{\link{synth}} for the inner/outer split semantics.}
  \item{genoud}{Forwarded to each placebo refit's \code{\link{synth}} call. Set to \code{TRUE} when the original fit used genoud, so placebos use the same optimizer.}
  \item{treatment_time}{Optional first post-treatment period. Defaults to \code{max(dataprep.res$tag$time.optimize.ssr) + 1}. Pre-treatment plot years before the SSR optimization window are excluded from post-period MSPE so they cannot inflate placebo p-values.}
  \item{keep_fits}{If \code{TRUE}, store the full \code{\link{synth}} return value (with \code{solution.w}, \code{solution.v}, etc.) on each placebo entry under the \code{fit} field. Default \code{FALSE} keeps the output light by storing only the gap series and MSPE summaries.}
}
\details{
For donor \eqn{i}, the swap moves donor \eqn{i}'s columns from \code{X0}, \code{Z0}, and \code{Y0plot} into the treated slots, and the original treated unit takes donor \eqn{i}'s former column in the control pool. The donor pool size is preserved.

Refits that error are caught with \code{tryCatch}; the corresponding \code{failed} flag is set and downstream functions exclude them from denominators.
}
\value{
An object of class \code{synth_placebos}, a list with components:
  \item{treated}{Named list with the real fit's gap series and MSPE summaries (\code{gap}, \code{pre_mspe}, \code{post_mspe}, \code{mspe_ratio}).}
  \item{placebos}{Named list of length \code{ncol(dataprep.res$X0)}; each element has the same shape as \code{treated} plus a \code{failed} flag and an \code{error_message} (\code{NA} on success, the captured \code{conditionMessage(e)} on \code{tryCatch} failure). When \code{keep_fits = TRUE} the entry also has a \code{fit} field carrying the full \code{\link{synth}} return value for that donor.}
  \item{time}{Plot horizon, equal to \code{dataprep.res$tag$time.plot}.}
  \item{pre_idx, post_idx}{Integer indices into \code{time}.}
  \item{donor_names}{Character vector of donor labels.}
  \item{failed}{Logical vector aligned with \code{donor_names}.}
}
\references{
Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic Control Methods for Comparative Case Studies. \emph{Journal of the American Statistical Association} 105 (490) 493--505.
}
\author{Jens Hainmueller and Alexis Diamond}
\note{
The function names \code{generate_placebos}, \code{mspe_test}, \code{mspe_plot}, and \code{plot_placebos} match those in the \pkg{SCtools} package by design. If both packages are loaded, namespace-qualify (e.g., \code{Synth::generate_placebos}).
}
\seealso{\code{\link{mspe_test}}, \code{\link{mspe_plot}}, \code{\link{plot_placebos}}, \code{\link{synth_inference}}.}
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
pl <- generate_placebos(fit, d)
print(pl)
mspe_test(pl)$pvalue
plot_placebos(pl)
}
}

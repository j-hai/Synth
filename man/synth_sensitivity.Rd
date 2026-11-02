\name{synth_sensitivity}
\alias{synth_sensitivity}
\alias{summary.synth_sensitivity}
\alias{print.synth_sensitivity}
\alias{plot.synth_sensitivity}
\alias{as.data.frame.synth_sensitivity}
\title{Sensitivity to Prespecified Synthetic Control Designs}
\description{
Independently refits \code{synth()} over an explicit registry of donor pools,
predictors, predictor aggregation windows and fitting periods. The treated
unit, treatment date, outcome and ATT evaluation periods remain fixed.
}
\usage{
synth_sensitivity(panel, baseline, specifications, att_periods,
  synth_args = list(), excluded_donors = numeric(),
  interface = c("synth_data", "dataprep"),
  treatment_time = baseline$treatment_time)

\method{summary}{synth_sensitivity}(object, ...)
\method{print}{synth_sensitivity}(x, ...)
\method{plot}{synth_sensitivity}(x,
  type = c("specification_curve", "paths"), ...)
\method{as.data.frame}{synth_sensitivity}(x, row.names = NULL,
  optional = FALSE, ...)
}
\arguments{
\item{panel}{Original panel data frame.}
\item{baseline}{Named list of \code{synth_data()} arguments, excluding
\code{panel}. With \code{interface = "dataprep"}, use \code{dataprep()}
argument names, excluding \code{foo}, and supply \code{treatment_time}
separately. Unit and time columns must be specified by name.}
\item{specifications}{Named list of named override lists. An empty list is the
unchanged design. An unchanged \code{baseline} is inserted if absent; that
name is reserved. With the advanced \code{dataprep} interface, entries can
also supply full configurations, provided all fixed fields match the baseline.}
\item{att_periods}{Nonempty, unique observed periods on or after treatment,
fixed for all specifications.}
\item{synth_args}{Named list of fixed solver options passed to \code{synth()}.
Matrix inputs cannot be overridden. The initial interface supports deterministic
\code{ipop} fits only; \code{genoud = TRUE} is not supported.}
\item{excluded_donors}{Numeric unit identifiers for known treated or
contaminated donors. A design containing one fails.}
\item{interface}{Preparation function whose argument names to use.}
\item{treatment_time}{First treated period. Defaults to the baseline's value
for \code{synth_data}; required for \code{dataprep}.}
\item{x, object}{A \code{synth_sensitivity} result.}
\item{type}{Plot all attempted effects or fitted trajectories.}
\item{row.names, optional}{Arguments passed to \code{as.data.frame()}.}
\item{...}{Additional arguments; passed to the initial \code{plot()} call
or \code{as.data.frame()} where applicable.}
}
\details{
Specify the registry before inspecting post-treatment estimates. All predictor
and fitting periods must be strictly pre-treatment, including special predictors.
Precomputed columns must themselves exclude future information; the runner
cannot infer their provenance. Researchers remain responsible for donor
eligibility beyond the explicit exclusion list.

The common trajectory covers every observed panel period. Missing or nonfinite
outcomes fail a specification instead of shortening its ATT period.
\code{pre_rmse} uses all observed pre-treatment periods, common across designs;
\code{fit_rmse} uses each design's fitting periods. No fit-quality cutoff is applied.
Warnings, including optimizer nonconvergence, mark fits as \code{warning} and
remain accessible. Finite estimates from such fits are retained. Failed designs
have missing estimates and a separate exception log. The default specification
curve displays every attempt, labels failures without assigning an effect value,
and marks fits with warnings using crosses.

\code{summary()} describes finite estimates, including warning-bearing fits,
and reports attempted, estimated, failed and warning counts. Sign shares use the
number of finite estimates as their denominator. Standard deviation is missing
when fewer than two estimates are finite or its value exceeds the floating-point
range. These are descriptive shares
among registered designs, not causal probabilities. Their dispersion does not
form a confidence interval. This varies designs for the original treated unit;
it is separate from in-space placebo inference. Pre-treatment holdout validation
is not part of this interface.

RMS summaries are scaled before squaring to avoid intermediate overflow.
ATT uses base R's \code{mean}; cancellation among extreme mixed-sign gaps can
lose small residuals at floating-point precision. Nonfinite aggregate summaries
are logged as failed designs.
}
\value{
\code{synth_sensitivity()} returns an S3 object with:
\describe{
\item{summary}{Data frame with \code{spec_id}, \code{att}, \code{pre_rmse},
\code{fit_rmse}, \code{n_donors} and \code{status}, one row per attempt.}
\item{paths}{Tidy data frame of observed, synthetic and gap trajectories.}
\item{weights}{Tidy data frame of unrounded donor weights.}
\item{failures, warnings}{Data frames preserving exceptions and warnings.}
\item{registry, baseline}{Merged configurations and the original baseline.}
\item{fits, prepared}{Native \code{synth()} and preparation objects keyed by
specification, preserving predictor weights and optimizer diagnostics.}
\item{metadata}{Common periods, exclusions, interface, package version and
resolved solver arguments.}
}
\code{summary()} returns a one-row dispersion data frame.
\code{as.data.frame()} returns the per-specification summary table.
\code{print()} and \code{plot()} return their input invisibly.
}
\seealso{\code{\link{synth_data}}, \code{\link{dataprep}}, \code{\link{synth}}}
\examples{
data(smoking)
baseline <- list(outcome = "cigsale", unit_col = "state_id", time_col = "year",
                 treated = 3, treatment_time = 1989, controls = c(1, 2, 4, 5),
                 predictors = "retprice", pre_periods = 1980:1988)
res <- synth_sensitivity(smoking, baseline,
                         list(short = list(pre_periods = 1984:1988)), 1989:2000)
summary(res)
as.data.frame(res)
}

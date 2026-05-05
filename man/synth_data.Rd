\name{synth_data}
\alias{synth_data}
\title{Build inputs for \code{synth()} from a panel data frame}
\description{
A friendlier wrapper around \code{\link{dataprep}}. Takes a long-format
panel data frame plus the names of the unit, time, and outcome columns,
and returns a \code{dataprep}-shaped list ready to pass to
\code{\link{synth}} and the inference functions.

Defaults:
\itemize{
\item \code{controls = NULL} uses every panel unit other than the treated one.
\item \code{predictors = NULL} fits the synthetic control on the outcome alone (via \code{special_predictors} or the implicit pre-period match).
\item \code{plot_periods = NULL} uses the full panel range.
\item \code{pre_periods = NULL} uses every panel time strictly before \code{treatment_time}.
}
}
\usage{
synth_data(panel,
           outcome,
           treated,
           controls = NULL,
           unit_col,
           time_col,
           treatment_time,
           predictors = NULL,
           predictors.op = "mean",
           special_predictors = list(),
           pre_periods = NULL,
           plot_periods = NULL,
           unit_names_col = NULL)
}
\arguments{
  \item{panel}{Long-format \code{data.frame} with one row per (unit, time).}
  \item{outcome}{Name of the outcome column (character).}
  \item{treated}{The treated unit. Either a numeric id (matched against \code{unit_col}) or a character name (requires \code{unit_names_col}).}
  \item{controls}{Optional vector of control units. Same id-or-name convention as \code{treated}. Defaults to "all other units in the panel".}
  \item{unit_col}{Name of the unit-id column (character). Must be numeric.}
  \item{time_col}{Name of the time column (character). Must be numeric.}
  \item{treatment_time}{Single numeric value: the first post-treatment period. Used as the SSR-window cutoff and as the default treatment date for downstream inference.}
  \item{predictors}{Character vector of predictor column names. \code{NULL} means rely entirely on \code{special_predictors}.}
  \item{predictors.op}{Aggregation op for \code{predictors} over \code{pre_periods}. Default \code{"mean"}.}
  \item{special_predictors}{List of \code{list(name, periods, op)} triples passed to \code{\link{dataprep}}.}
  \item{pre_periods}{Optional integer vector of pre-treatment time values. Defaults to every \code{time_col} value strictly before \code{treatment_time}.}
  \item{plot_periods}{Optional integer vector of times for the full plot horizon. Defaults to the full panel range.}
  \item{unit_names_col}{Optional column name carrying readable unit labels. Required when \code{treated} or \code{controls} are passed as names.}
}
\value{A \code{dataprep}-shaped list (the same structure returned by \code{\link{dataprep}}). The list also carries \code{tag$synth_data_treatment_time} and an \code{attr(., "synth_data_call")} for debugging.}
\seealso{\code{\link{dataprep}} for the long-form constructor; \code{\link{synth}}, \code{\link{synth_inference}}, \code{\link{generate_placebos}} for what to do next.}
\examples{
\dontrun{
data(basque)
# Equivalent to the long dataprep() example, in one call:
dp <- synth_data(
  panel              = basque,
  outcome            = "gdpcap",
  unit_col           = "regionno",
  time_col           = "year",
  treated            = 17,                 # Basque country
  controls           = c(2:16, 18),
  treatment_time     = 1970,
  predictors         = c("school.illit", "school.prim", "school.med",
                         "school.high", "school.post.high", "invest"),
  special_predictors = list(
    list("gdpcap",          1960:1969,           "mean"),
    list("sec.agriculture", seq(1961, 1969, 2),  "mean")
  ),
  unit_names_col     = "regionname"
)
fit <- synth(dp)
inf <- synth_inference(fit, dp, method = "conformal", alpha = 0.10)
}
}

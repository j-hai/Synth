\name{smoking}
\alias{smoking}
\docType{data}
\title{Annual State-Level Cigarette Sales in the United States, 1970-2000}
\description{
A panel of per-capita cigarette sales for 39 US states from 1970
through 2000, plus four covariates (per-capita log income, beer
consumption, share of population aged 15-24, and the retail price of
cigarettes). This is the dataset used in the canonical synthetic
control application of Abadie, Diamond, and Hainmueller (2010), which
estimated the effect of California's 1988 Proposition 99 on cigarette
consumption.
}
\usage{data(smoking)}
\format{
A \code{data.frame} with 1209 rows and 8 columns:
\describe{
  \item{\code{state_id}}{Numeric state identifier (3 = California).}
  \item{\code{state_name}}{State name as a character string.}
  \item{\code{year}}{Calendar year (1970-2000).}
  \item{\code{cigsale}}{Per-capita cigarette sales in packs.}
  \item{\code{lnincome}}{Log per-capita state income.}
  \item{\code{beer}}{Per-capita beer consumption.}
  \item{\code{age15to24}}{Share of population aged 15-24.}
  \item{\code{retprice}}{Retail price of cigarettes.}
}
\code{lnincome} and \code{beer} are missing for some early years; the
canonical Proposition 99 analysis matches on covariate averages over
windows where the data are observed.
}
\source{
Compiled from the data files distributed with Abadie, Diamond, and
Hainmueller (2010) and shipped with the Stata \code{synth} package.
}
\references{
Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic Control
Methods for Comparative Case Studies: Estimating the Effect of
California's Tobacco Control Program. \emph{Journal of the American
Statistical Association}, 105(490), 493-505.
}
\seealso{\code{\link{basque}}, \code{\link{synth}}, \code{\link{synth_inference}}.}
\examples{
\dontrun{
data(smoking)

# California is state 3; treatment is Proposition 99 in late 1988,
# so 1989 is the first post-treatment year.
ca_id <- unique(smoking$state_id[smoking$state_name == "California"])

dp <- synth_data(
  panel              = smoking,
  outcome            = "cigsale",
  unit_col           = "state_id",
  time_col           = "year",
  treated            = ca_id,
  treatment_time     = 1989,
  predictors         = c("lnincome", "age15to24", "retprice", "beer"),
  special_predictors = list(
    list("cigsale", 1988, "mean"),
    list("cigsale", 1980, "mean"),
    list("cigsale", 1975, "mean")
  ),
  unit_names_col     = "state_name"
)

fit <- synth(dp)
inf <- synth_inference(fit, dp, method = "conformal", alpha = 0.10)
plot(inf)
}
}
\keyword{datasets}

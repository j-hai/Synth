\name{synth_mspe_test}
\alias{synth_mspe_test}
\title{One-sided placebo p-value via post/pre MSPE ratio}
\description{
Computes a one-sided p-value for the treated unit's post/pre mean squared prediction error (MSPE) ratio against the empirical distribution of placebo ratios. Operates on the output of \code{\link{synth_placebos}}.
}
\usage{
synth_mspe_test(placebos)
}
\arguments{
  \item{placebos}{Output of \code{\link{synth_placebos}}.}
}
\details{
The p-value is the empirical rank
\deqn{p = \mathrm{mean}\bigl( \{r_\mathrm{treated}\} \cup \{r_i : r_i \mbox{ valid}\} \ge r_\mathrm{treated} \bigr),}{p = mean( c(r_treated, r_i for valid i) >= r_treated ),}
where \eqn{r_\mathrm{treated}}{r_treated} is the treated unit's post/pre MSPE ratio and \eqn{r_i}{r_i} is the corresponding ratio for placebo donor \eqn{i}{i}. Failed refits are excluded from the denominator.
}
\value{
A list with elements
  \item{mspe_ratio_treated}{The treated unit's post/pre MSPE ratio.}
  \item{mspe_ratios_placebos}{Numeric vector of placebo ratios, with \code{NA} for failed refits.}
  \item{pvalue}{One-sided empirical p-value.}
  \item{n_valid_placebos}{Count of placebos with non-missing ratios.}
}
\references{
Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic Control Methods for Comparative Case Studies. \emph{Journal of the American Statistical Association} 105 (490) 493--505.
}
\seealso{\code{\link{synth_placebos}}, \code{\link{synth_mspe_plot}}, \code{\link{plot.synth_placebos}}.}

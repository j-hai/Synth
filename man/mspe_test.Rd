\name{mspe_test}
\alias{mspe_test}
\title{One-sided placebo p-value via post/pre MSPE ratio}
\description{
Computes a one-sided p-value for the treated unit's post/pre mean squared prediction error (MSPE) ratio against the empirical distribution of placebo ratios. Operates on the output of \code{\link{generate_placebos}}.
}
\usage{
mspe_test(placebos)
}
\arguments{
  \item{placebos}{Output of \code{\link{generate_placebos}}.}
}
\details{
The p-value is the empirical rank
\deqn{p = \mathrm{mean}\bigl( \{r_\mathrm{treated}\} \cup \{r_i : r_i \mbox{ valid}\} \ge r_\mathrm{treated} \bigr),}
where \eqn{r_\mathrm{treated}} is the treated unit's post/pre MSPE ratio and \eqn{r_i} is the corresponding ratio for placebo donor \eqn{i}. Failed refits are excluded from the denominator.
}
\value{
A list with elements
  \item{mspe_ratio_treated}{The treated unit's post/pre MSPE ratio.}
  \item{mspe_ratios_placebos}{Numeric vector of placebo ratios, with \code{NA} for failed refits.}
  \item{pvalue}{One-sided empirical p-value.}
  \item{n_valid_placebos}{Count of placebos with finite ratios.}
}
\references{
Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic Control Methods for Comparative Case Studies. \emph{Journal of the American Statistical Association} 105 (490) 493--505.
}
\seealso{\code{\link{generate_placebos}}, \code{\link{mspe_plot}}, \code{\link{plot_placebos}}.}

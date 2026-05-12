\name{synth}
\alias{synth}
\title{
Constructs synthetic control units for comparative case studies
}
\description{
Implements the synthetic control method for causal inference in comparative case studies as developed in Abadie and Gardeazabal (2003) and Abadie, Diamond, and Hainmueller (2010, 2011, 2014). \code{\link{synth}} estimates the effect of an intervention by comparing the evolution of an aggregate outcome for a unit affected by the intervention to the evolution of the same aggregate outcome for a synthetic control group.

\code{\link{synth}} constructs this synthetic control group by searching for a weighted combination of control units chosen to approximate the unit affected by the intervention in terms of characteristics that are predictive of the outcome. The evolution of the outcome for the resulting synthetic control group is an estimate of the counterfactual of what would have been observed for the affected unit in the absence of the intervention.

\code{\link{synth}} can also be used to conduct a variety of placebo and permutation tests that produce informative inference regardless of the number of available comparison units and the number of available time periods. See Abadie and Gardeazabal (2003), Abadie, Diamond, and Hainmueller (2010, 2011, 2014) for details.

\code{\link{synth}} requires the user to supply four matrices as its main arguments. These matrices are named X0, X1, Z1, and Z0 accordingly. X1 and X0 contain the predictor values for the treated unit and the control units respectively. Z1 and Z0 contain the outcome variable for the pre-intervention period for the treated unit and the control units respectively. The pre-intervention period refers to the time period prior to the intervention, over which the mean squared prediction error (MSPE) should be minimized. The MSPE refers to the squared deviations between the outcome for the treated unit and the synthetic control unit summed over all pre-intervention periods specified in Z1 and Z0.

Creating the matrices X1, X0, Z1, and Z0 from a (panel) dataset can be tedious. Therefore, the \pkg{Synth} package offers a preparatory function called \code{\link{dataprep}} that allows the user to easily create all inputs required for \code{\link{synth}}. By first calling \code{\link{dataprep}}, the user creates a single list object called \code{data.prep.obj} that contains all essential data elements to run \code{synth}.

A usual sequence of commands to implement the synthetic control method is to first call \code{\link{dataprep}} to prepare the data, then call \code{\link{synth}} to construct the synthetic control group, and finally summarize results using the functions \code{\link{synth.tab}}, \code{\link{path.plot}}, or \code{\link{gaps.plot}}.

An example of this sequence is provided in the documentation to \code{\link{dataprep}}. This procedure is strongly recommended. Alternatively, the user may provide their own preprocessed data matrices and load them into \code{\link{synth}} via the X0, X1, Z1, and Z0 arguments. In this case, no \code{data.prep.obj} should be specified.

The output from \code{\link{synth}} is a list object that contains the weights on predictors (\code{solution.V}) and weights on control units (\code{solution.W}) that define contributions to the synthetic control unit.
}
\usage{
synth(data.prep.obj = NULL,
      X1 = NULL, X0 = NULL,
      Z0 = NULL, Z1 = NULL,
      custom.v = NULL,
      optimxmethod = c("Nelder-Mead", "BFGS"),
      genoud = FALSE, quadopt = "ipop",
      quadopt_inner = NULL,
      quadopt_outer = NULL,
      cvxr_pars = list(),
      cvxr_pars_inner = NULL,
      cvxr_pars_outer = NULL,
      torch_pars = list(),
      torch_pars_inner = NULL,
      torch_pars_outer = NULL,
      Margin.ipop = 5e-04,
      Sigf.ipop = 5,
      Bound.ipop = 10,
      verbose = FALSE, ...)
}
\arguments{
  \item{data.prep.obj}{
The object produced by \code{\link{dataprep}}. This object contains all information about X0, X1, Z1, and Z0. If \code{data.prep.obj} is supplied, none of X0, X1, Z1, and Z0 should be manually specified.
}
  \item{X1}{Matrix of treated predictor data. Rows correspond to predictors, columns to a single treated unit.}
  \item{X0}{Matrix of control units’ predictor data. Rows correspond to predictors, columns to control units (>=2).}
  \item{Z1}{Matrix of treated outcome data for the pre-treatment periods over which MSPE is minimized.}
  \item{Z0}{Matrix of control units’ outcome data for the pre-treatment periods over which MSPE is minimized.}
  \item{custom.v}{
Vector of weights for predictors supplied by the user. Uses \code{synth} to bypass optimization for \code{solution.V}. See Details.
}
  \item{optimxmethod}{
Character vector specifying optimization algorithms to be used. Permissible values are all optimization algorithms currently implemented in the function \code{\link[optimx:optimx]{optimx}} (see that function for details). If multiple algorithms are specified, \code{\link{synth}} will run all chosen algorithms and return the best-performing result. If \code{"All"} is specified, all algorithms in \code{\link[optimx:optimx]{optimx}} are tried.
}
  \item{genoud}{
Logical flag. If \code{TRUE}, \code{\link{synth}} performs a two-step optimization. In the first step, \code{\link[rgenoud:genoud]{genoud}} is used to obtain a global solution. In the second step, the results are passed to the algorithm(s) chosen in \code{optimxmethod} for local optimization. This two-step procedure is slower but may yield lower loss for irregular search spaces.
}
  \item{quadopt}{
Character specifying the routine for quadratic optimization over W weights. One of \code{"ipop"} (default; \code{\link[kernlab:ipop]{ipop}} from \pkg{kernlab}, behavior unchanged from earlier versions of \pkg{Synth}), \code{"cvxr"} (CVXR with OSQP as the default solver; requires the \pkg{CVXR} package, in \code{Suggests:}), or \code{"torch"} (Frank-Wolfe simplex least squares via the \pkg{torch} package, also in \code{Suggests:}; supports CPU, CUDA, and Apple MPS via \code{torch_pars}). The two new backends are opt-in for users with larger panels or who prefer modern convex-optimization or autodiff/GPU machinery; on small panels they agree with ipop to within solver tolerance.

When \code{quadopt} alone is specified it applies to both the inner and outer QP solves. To use different backends for the two stages — e.g. fast \code{ipop} for the V-search loop and a modern solver only for the final W solve — use \code{quadopt_inner} and \code{quadopt_outer} below.
}
  \item{quadopt_inner}{
Optional character. If non-\code{NULL}, overrides \code{quadopt} for the QP solves inside \code{\link{fn.V}} during the V-search. Defaults to \code{NULL}, which means "inherit \code{quadopt}".
}
  \item{quadopt_outer}{
Optional character. If non-\code{NULL}, overrides \code{quadopt} for the final W solve once V is fixed. Defaults to \code{NULL}, which means "inherit \code{quadopt}". The common pattern is \code{quadopt_outer = "cvxr"} (or \code{"torch"}) with \code{quadopt} left at \code{"ipop"}: V-search runs at ipop's speed and only the final W is solved with the modern backend.
}
  \item{cvxr_pars}{
Optional named list of tuning parameters forwarded to the CVXR backend when \code{quadopt} or \code{quadopt_outer} is \code{"cvxr"}. Recognized fields: \code{solver} (default \code{"OSQP"}, a hard CVXR dependency that ships everywhere CVXR does; other CVXR-supported solvers like \code{"SCS"}, \code{"ECOS"} (requires \pkg{ECOSolveR}), or \code{"MOSEK"} (requires a MOSEK license) can be passed), \code{eps} (default \code{1e-8}), and \code{max_iter} (default \code{5000}). The generic \code{eps} and \code{max_iter} are translated to whichever parameter names the chosen solver expects.
}
  \item{torch_pars}{
Optional named list of tuning parameters forwarded to the torch backend when \code{quadopt} or \code{quadopt_outer} is \code{"torch"}. Recognized fields: \code{max_iter} (default \code{500}), \code{tol} (default \code{1e-8}), \code{device} (default \code{"cpu"}; pass \code{"cuda"} for NVIDIA GPU or \code{"mps"} for Apple Silicon), and \code{dtype} (\code{"float64"} default or \code{"float32"} for speed).
}
  \item{cvxr_pars_inner, cvxr_pars_outer, torch_pars_inner, torch_pars_outer}{
Optional per-stage overrides for backend tuning. Each defaults to \code{NULL}, in which case the matching master list (\code{cvxr_pars} or \code{torch_pars}) is used. The common pattern is to pass a tighter \code{*_outer} configuration (e.g.\ smaller \code{eps} or larger \code{max_iter}) for the single final W solve while leaving the V-search at lighter defaults.
}
  \item{Margin.ipop}{
Setting for the \code{ipop} optimization routine: how close we get to the constraints (see \code{\link[kernlab:ipop]{ipop}} for details).
}
  \item{Sigf.ipop}{
Setting for the \code{ipop} optimization routine: precision in significant figures (default: 7; see \code{\link[kernlab:ipop]{ipop}} for details).
}
  \item{Bound.ipop}{
Setting for the \code{ipop} optimization routine: clipping bound for variables (see \code{\link[kernlab:ipop]{ipop}} for details).
}
  \item{verbose}{Logical flag. If \code{TRUE}, intermediate results are displayed.}
  \item{\dots}{Additional arguments passed to \code{\link[optimx:optimx]{optimx}} or \code{\link[rgenoud:genoud]{genoud}}.}
}
\details{
As proposed in Abadie and Gardeazabal (2003) and Abadie, Diamond, and Hainmueller (2010), \code{\link{synth}} searches for the set of weights that generate the best-fitting convex combination of control units. The predictor weight matrix V is chosen among positive definite diagonal matrices such that MSPE is minimized for the pre-intervention period.

Alternatively, the user may supply a vector of V weights based on a subjective assessment of the predictive power of the variables in X1 and X0. In this case, specify \code{custom.V} in \code{\link{synth}}, and the optimization over V matrices is bypassed.
}
\value{
  \item{solution.v}{Vector of predictor weights.}
  \item{solution.w}{Vector of weights across control units.}
  \item{loss.v}{MSPE from optimization over V and W weights.}
  \item{loss.w}{Loss from optimization over W weights.}
  \item{custom.v}{If specified, returns the user-supplied weight vector.}
  \item{rgV.optim}{Results from \code{optimx()} minimization, useful for diagnostics.}
}
\references{
Abadie, A., Diamond, A., Hainmueller, J. (2014). Comparative Politics and the Synthetic Control Method. \emph{American Journal of Political Science}.

Abadie, A., Diamond, A., Hainmueller, J. (2011). Synth: An R Package for Synthetic Control Methods in Comparative Case Studies. \emph{Journal of Statistical Software}, 42(13), 1–17.

Abadie, A., Diamond, A., Hainmueller, J. (2010). Synthetic Control Methods for Comparative Case Studies: Estimating the Effect of California's Tobacco Control Program. \emph{Journal of the American Statistical Association}, 105(490), 493–505.

Abadie, A., and Gardeazabal, J. (2003). Economic Costs of Conflict: A Case Study of the Basque Country. \emph{American Economic Review}, 93(1), 113–132.
}
\author{Jens Hainmueller and Alexis Diamond}
\seealso{
\code{\link{dataprep}}, \code{\link{gaps.plot}}, \code{\link{path.plot}}, \code{\link{synth.tab}}
}
\examples{
\donttest{
data(synth.data)
dataprep.out <- dataprep(foo = synth.data,
   predictors = c("X1","X2","X3"),
   predictors.op = "mean",
   dependent = "Y",
   unit.variable = "unit.num",
   time.variable = "year",
   special.predictors = list(
      list("Y",1991,"mean"),
      list("Y",1985,"mean"),
      list("Y",1980,"mean")),
   treatment.identifier = 7,
   controls.identifier = c(29,2,13,17,32,38),
   time.predictors.prior = 1984:1989,
   time.optimize.ssr = 1984:1990,
   unit.names.variable = "name",
   time.plot = 1984:1996)
synth.out <- synth(dataprep.out)
path.plot(dataprep.res = dataprep.out, synth.res = synth.out)
gaps.plot(dataprep.res = dataprep.out, synth.res = synth.out)
}
\dontrun{
## Alternative quadopt backends (Synth 1.2-0+; both in Suggests:).
## Defaults to ipop. CVXR uses OSQP by default (a CVXR Imports, so
## always available); pass cvxr_pars = list(solver = "SCS") or
## "ECOS" (the latter needs ECOSolveR). Torch uses Frank-Wolfe
## simplex least squares with exact line search and can run on
## GPU/MPS via the device argument.
##
## On the Basque example all three backends produce essentially the
## same synthetic control: identical pre-MSPE (0.0089), post-MSPE
## within 0.001, and ATT estimates within 0.001 of each other. The
## CVXR and torch backends are slower because they are invoked on
## every fn.V() evaluation inside optimx's V-search.

# install.packages("CVXR")
synth.cvxr <- synth(dataprep.out, quadopt = "cvxr")

# install.packages("torch"); torch::install_torch()
synth.torch <- synth(dataprep.out, quadopt = "torch")

## To keep V-search fast (ipop) and use a modern solver only for
## the final W solve, set quadopt_outer alone:
synth.fast.cvxr <- synth(dataprep.out, quadopt_outer = "cvxr")
}
}

\name{fn.V}
\alias{fn.V}
\title{
Loss Function for nested optimization of W and V weights
}
\description{
Loss function for the nested optimization of W and V weights used for constructing synthetic control groups according to the methods outlined in Abadie and Gardeazabal (2003) and Abadie, Diamond, Hainmueller (2010, 2011, 2014) (see references). This function is called by \code{\link{synth}} internally, and should not be called manually by a normal user.
}
\usage{
fn.V(variables.v = stop("variables.v missing"),
X0.scaled = stop("X0.scaled missing"), 
X1.scaled = stop("X1.scaled missing"), 
Z0 = stop("Z0 missing"), 
Z1 = stop("Z1 missing"), 
margin.ipop = 5e-04, 
sigf.ipop = 5, 
bound.ipop = 10,
quadopt = "ipop",
cvxr_pars = list(),
torch_pars = list())
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{variables.v}{
1 by k a vector of v weights.
}
  \item{X0.scaled}{
matrix of controls' predictor data. nrows = number of predictors and (possibly) special predictors. ncols = number of control units.
}
  \item{X1.scaled}{matrix of treated predictor data. nrows = number of predictors and (possibly) special predictors. ncols = one.
}
  \item{Z0}{matrix of controls' outcome data for the pre-treatment periods over which MSPE is to be minimized. nrows = number of pre-treatment periods. ncols = number of control units.
}
  \item{Z1}{
matrix of treated outcome data for the pre-treatment periods over which MSPE is to be minimized. nrows = number of pre-treatment periods. ncols = one.
}
  \item{margin.ipop}{
setting for ipop optimization routine: how close we get to the constrains 
(see \code{\link[kernlab:ipop]{ipop}} for details)
}
  \item{sigf.ipop}{
setting for ipop optimization routine: Precision (default: 7 significant figures) 
(see \code{\link[kernlab:ipop]{ipop}} for details)
}
  \item{bound.ipop}{
setting for ipop optimization routine: Clipping bound for the variables 
(see \code{\link[kernlab:ipop]{ipop}} for details)
}
  \item{quadopt}{
string vector that specifies the routine for quadratic optimization over w weights.
One of \code{"ipop"} (default; see \code{\link[kernlab:ipop]{ipop}}), \code{"cvxr"} (CVXR + ECOS), or \code{"torch"} (Frank-Wolfe simplex least squares via the \pkg{torch} package).
}
  \item{cvxr_pars}{
Optional named list of CVXR backend tuning. Recognized fields: \code{solver} (default \code{"ECOS"}), \code{eps} (default \code{1e-8}), \code{max_iter} (default \code{5000}). Ignored unless \code{quadopt = "cvxr"}.
}
  \item{torch_pars}{
Optional named list of torch backend tuning. Recognized fields: \code{max_iter} (default \code{500}), \code{tol} (default \code{1e-8}), \code{device} (default \code{"cpu"}; \code{"cuda"} or \code{"mps"} for GPU), \code{dtype} (default \code{"float64"}). Ignored unless \code{quadopt = "torch"}. Both \code{cvxr_pars} and \code{torch_pars} are forwarded by \code{\link{synth}} to every \code{fn.V} invocation during V-search, so the inner solves use the same backend configuration as the final W solve.
}

}
\value{
A scalar that contains the function value.
}
\references{

Abadie, A., Diamond, A., Hainmueller, J. (2014). Comparative Politics and the Synthetic Control Method. \emph{American Journal of Political Science} 59(2): 495-510.

Synthetic : An R Package for Synthetic Control Methods in Comparative Case Studies. \emph{Journal of Statistical Software} 42 (13) 1--17.
       
Abadie, A., Diamond, A., Hainmueller, J. (2011). Synth: An R Package for Synthetic Control Methods in Comparative Case Studies. \emph{Journal of Statistical Software} 42 (13) 1--17.

Abadie A, Diamond A, Hainmueller J (2010). Synthetic Control Methods for Comparative Case Studies: Estimating the Effect of California's Tobacco Control Program. \emph{Journal of the American Statistical Association} 105 (490) 493--505.
     
Abadie, A. and Gardeazabal, J. (2003) Economic Costs of Conflict: A Case Study of the Basque Country \emph{American Economic Review} 93 (1) 113--132.
  
}


\author{
Jens Hainmueller and Alexis Diamond
}

\seealso{ \code{\link{synth}}, \code{\link{dataprep}}, \code{\link{gaps.plot}}, \code{\link{path.plot}},
 \code{\link{synth.tab}}
}




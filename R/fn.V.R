fn.V <-
function(
           variables.v = stop("variables.v missing"),
           X0.scaled = stop("X0.scaled missing"),
           X1.scaled = stop("X1.scaled missing"),
           Z0 = stop("Z0 missing"),
           Z1 = stop("Z1 missing"),
           margin.ipop = 0.0005,
           sigf.ipop = 5,
           bound.ipop = 10,
           quadopt = "ipop",
           cvxr_pars = list(),
           torch_pars = list()
           )

  {

    # check quadopt: route LowRankQP through .solve_w() so it errors with
    # the canonical message; reject other unknown options up front.
    if (!(quadopt %in% c("ipop", "cvxr", "torch", "LowRankQP"))) {
      stop(sprintf(
        "Unknown quadopt = \"%s\"; supported values are \"ipop\", \"cvxr\", \"torch\"",
        quadopt))
    }

    # rescale par
    V <- diag(x=as.numeric(abs(variables.v)/sum(abs(variables.v))),
              nrow=length(variables.v),ncol=length(variables.v))

    # set up QP problem
    H <- t(X0.scaled) %*% V %*% (X0.scaled)
    a <- X1.scaled
    c <- -1*c(t(a) %*% V %*% (X0.scaled) )

    # run QP and obtain w weights
    solution.w <- .solve_w(
      H, c, quadopt = quadopt,
      ipop_pars  = list(margin = margin.ipop, sigf = sigf.ipop,
                        bound  = bound.ipop,  maxiter = 1000),
      cvxr_pars  = cvxr_pars,
      torch_pars = torch_pars
    )

    # compute losses
    loss.w <- as.numeric(t(X1.scaled - X0.scaled %*% solution.w) %*%
      (V) %*% (X1.scaled - X0.scaled %*% solution.w))

    loss.v <- as.numeric(t(Z1 - Z0 %*% solution.w) %*%
      ( Z1 - Z0 %*% solution.w ))
    loss.v <- loss.v/nrow(Z0)

    return(invisible(loss.v))
  }

# Internal QP dispatcher used by synth() and fn.V().
#
# Solves the simplex-constrained quadratic program
#   minimize   w' H w + 2 c' w
#   subject to sum(w) = 1, 0 <= w <= 1
# with one of three backends:
#   "ipop"  -- kernlab::ipop (default; behaves identically to <= 1.1-10)
#   "cvxr"  -- CVXR + ECOS (Suggests CVXR)
#   "torch" -- Frank-Wolfe simplex LS via the torch package (Suggests torch)
#
# Returns a one-column matrix of length n with rownames == colnames(X0).

.solve_w <-
function(H, c_vec,
         quadopt   = "ipop",
         ipop_pars = list(margin = 0.0005, sigf = 5, bound = 10, maxiter = 1000),
         cvxr_pars = list(solver = "ECOS", eps = 1e-8, max_iter = 5000),
         torch_pars = list(max_iter = 500, tol = 1e-8,
                           device = "cpu", dtype = "float64"))
  {
    if (quadopt == "ipop") {
      return(.solve_w_ipop(H, c_vec, ipop_pars))
    } else if (quadopt == "cvxr") {
      return(.solve_w_cvxr(H, c_vec, cvxr_pars))
    } else if (quadopt == "torch") {
      return(.solve_w_torch(H, c_vec, torch_pars))
    } else if (quadopt == "LowRankQP") {
      stop("LowRankQP is no longer supported; please use quadopt = \"ipop\" instead")
    } else {
      stop(sprintf(
        "Unknown quadopt = \"%s\"; supported values are \"ipop\", \"cvxr\", \"torch\"",
        quadopt))
    }
  }

.solve_w_ipop <-
function(H, c_vec, pars)
  {
    n <- length(c_vec)
    A <- t(rep(1, n))
    res <- kernlab::ipop(c = c_vec, H = H, A = A, b = 1,
                        l = rep(0, n), u = rep(1, n), r = 0,
                        margin = pars$margin %||% 0.0005,
                        sigf   = pars$sigf   %||% 5,
                        bound  = pars$bound  %||% 10,
                        maxiter = pars$maxiter %||% 1000)
    as.matrix(kernlab::primal(res))
  }

.solve_w_cvxr <-
function(H, c_vec, pars)
  {
    if (!requireNamespace("CVXR", quietly = TRUE)) {
      stop("CVXR is not installed. Install with: install.packages(\"CVXR\")")
    }
    n <- length(c_vec)
    w <- CVXR::Variable(n)
    obj <- CVXR::Minimize(CVXR::quad_form(w, H) + 2 * sum(c_vec * w))
    prob <- CVXR::Problem(obj, list(w >= 0, sum(w) == 1))
    # Use CVXR::psolve (not CVXR::solve) -- the colliding `solve`
    # export was removed from CVXR in a recent release to avoid
    # masking base::solve; psolve has been the documented
    # Problem-solving entry point for years.
    res <- CVXR::psolve(prob,
                        solver = pars$solver %||% "ECOS",
                        FEASTOL = pars$eps    %||% 1e-8,
                        RELTOL  = pars$eps    %||% 1e-8,
                        ABSTOL  = pars$eps    %||% 1e-8,
                        num_iter = pars$max_iter %||% 5000)
    if (!(res$status %in% c("optimal", "optimal_inaccurate"))) {
      stop(sprintf("CVXR solver returned status: %s", res$status))
    }
    val <- res$getValue(w)
    val <- pmax(val, 0)
    val <- val / sum(val)
    as.matrix(val)
  }

.solve_w_torch <-
function(H, c_vec, pars)
  {
    if (!requireNamespace("torch", quietly = TRUE)) {
      stop("torch is not installed. Install with: install.packages(\"torch\"); torch::install_torch()")
    }
    if (!torch::torch_is_installed()) {
      stop("libtorch backend not installed. Run: torch::install_torch()")
    }
    max_iter <- pars$max_iter %||% 500
    tol      <- pars$tol      %||% 1e-8
    device   <- pars$device   %||% "cpu"
    dtype    <- pars$dtype    %||% "float64"
    dt <- if (identical(dtype, "float64")) torch::torch_double() else torch::torch_float()

    H_t <- torch::torch_tensor(H,     dtype = dt, device = device)
    c_t <- torch::torch_tensor(as.numeric(c_vec), dtype = dt, device = device)
    n   <- length(c_vec)
    w   <- torch::torch_full(c(n), 1 / n, dtype = dt, device = device)

    # Frank-Wolfe with exact line search. The objective
    #   f(w) = w' H w + 2 c' w
    # is quadratic in eta along d = s - w; the closed-form minimum is
    #   eta* = clip(-d' grad / (2 d' H d), 0, 1)
    # which converges much faster than the textbook 2/(k+2) schedule.
    for (k in seq_len(max_iter)) {
      g  <- 2 * (torch::torch_matmul(H_t, w) + c_t)
      i  <- torch::torch_argmin(g)$item()
      s  <- torch::torch_zeros_like(w)
      s[i] <- 1
      gap <- ((w - s) * g)$sum()$item()
      if (gap < tol) break
      d   <- s - w
      dHd <- (torch::torch_matmul(H_t, d) * d)$sum()$item()
      eta <- if (dHd > 0) max(0, min(1, gap / (2 * dHd))) else 2 / (k + 2)
      w <- w + eta * d
    }
    w_num <- as.numeric(torch::as_array(w$to(device = "cpu")))
    w_num <- pmax(w_num, 0)
    w_num <- w_num / sum(w_num)
    as.matrix(w_num)
  }

`%||%` <- function(a, b) if (is.null(a)) b else a

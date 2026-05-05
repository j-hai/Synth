# Synth 1.2-0

## Bug fixes (vs the unreleased 1.2-0 RC1 from earlier in this development cycle)

* `synth_inference()` and `generate_placebos()` previously classified
  any plot-horizon year not in `time.optimize.ssr` as post-treatment.
  This silently mixed pre-treatment plot years before the SSR window
  (e.g. 1955-1959 in the Basque example with
  `time.optimize.ssr = 1960:1969`) into the post-period denominator,
  inflating `post_mspe`, `mspe_ratio`, and the `mspe_test()` p-value.
  Both now classify post as `time.plot >= treatment_time`, with the
  default `treatment_time = max(time.optimize.ssr) + 1`. A new
  `treatment_time` argument lets users override.

* `synth_inference(method = "conformal")` now uses the order statistic
  at rank `k = ceiling((n + 1) * (1 - alpha))` instead of
  `quantile(.., 1 - alpha, type = 1)`. The former is the rank that
  delivers exact finite-sample `(1 - alpha)` coverage under
  exchangeability; the latter selects rank `ceiling(n * (1 - alpha))`
  and slightly under-covers. When `n` is too small for the requested
  coverage, the function now warns and returns `Inf` for
  `conformal_q` instead of silently using the maximum residual.

## New arguments wired through `synth()` and `generate_placebos()`

* `synth()` now accepts `cvxr_pars` and `torch_pars` lists for tuning
  the `quadopt = "cvxr"` and `quadopt = "torch"` backends (e.g.
  `torch_pars = list(device = "mps")` for Apple Silicon GPU). These
  were supported internally by `.solve_w()` but were not previously
  exposed at the public API.

* `generate_placebos()` now exposes `genoud`, `cvxr_pars`,
  `torch_pars`, and `treatment_time`. Match these to the configuration
  that produced the real fit so placebos use the same optimizer and
  the same post-period definition.

## New: post-period inference

* `synth_inference()` returns a prediction band around the synthetic
  counterfactual. Two methods are available:

    * `method = "conformal"` (default) — split-conformal intervals
      (Chernozhukov, Wuthrich, Zhu 2021), finite-sample valid under
      exchangeability of pre-period residuals. Half-width is the
      `(1 - alpha)`-quantile of `|gap_pre|`.
    * `method = "parametric"` — Gaussian-residual intervals.
      Half-width is `qnorm(1 - alpha/2) * sd(gap_pre)`.

  Output is an S3 object of class `c("synth_<method>", "synth_inference")`
  with `print()` and `plot()` methods. The `plot()` method overlays the
  band on the treated and synthetic series.

* `generate_placebos()`, `mspe_test()`, `mspe_plot()`, `plot_placebos()`
  implement the in-space placebo workflow from Abadie, Diamond, and
  Hainmueller (2010). `generate_placebos()` swaps each donor into the
  treated slot, refits `synth()`, and returns a `synth_placebos` object.
  `mspe_test()` returns a one-sided p-value via the empirical rank of
  the treated unit's post/pre MSPE ratio. The function names match
  those in the `SCtools` package by design — migration is a verbatim
  rename and you can namespace-qualify (e.g., `Synth::generate_placebos`)
  if both packages are loaded.

* No new package dependencies. Optional `parallel = TRUE` in
  `generate_placebos()` uses `parallel::mclapply` on non-Windows.

## Validity caveats

* Both prediction-interval methods produce constant-width bands and
  do not separately quantify in-sample uncertainty about the synthetic
  weights. Users who need period-varying intervals or in-sample/
  out-of-sample uncertainty decomposition should see the `scpi`
  package (Cattaneo, Feng, Palomba, Titiunik).
* Conformal validity is exact under exchangeability of pre-period
  residuals; parametric validity assumes i.i.d. Gaussian residuals.
  Both are approximate when outcomes are autocorrelated.

## Optional alternative QP backends

* `synth()` and `fn.V()` gain two new opt-in values for `quadopt`:

    * `quadopt = "cvxr"` solves the W-step via the `CVXR` package
      (default solver: ECOS). Adds no required dependency; `CVXR` lives
      in `Suggests:` and is loaded only when requested.
    * `quadopt = "torch"` solves the W-step via Frank-Wolfe simplex
      least squares using the `torch` package, with optional GPU/MPS
      support (`torch_pars = list(device = "cuda")` or `"mps"`). Also
      in `Suggests:`. The first use of `torch` in a session may
      require `torch::install_torch()` to download libtorch.

  `quadopt = "ipop"` remains the default and produces output identical
  to `<= 1.1-10`. The new backends agree with ipop on the canonical
  examples to within solver tolerance and exist for users with larger
  panels who prefer modern convex-optimization solvers (CVXR) or
  autodiff/GPU machinery (torch). See the `?synth` Details section
  and the inference vignette for guidance on choosing a backend.

* New `quadopt_inner` and `quadopt_outer` arguments on `synth()` and
  `generate_placebos()` let users pick different backends for the two
  QP stages. The V-search calls `fn.V()` hundreds of times via
  `optimx`; running CVXR or torch on every call is much slower than
  ipop. Setting `quadopt_outer = "cvxr"` (or `"torch"`) with `quadopt`
  left at `"ipop"` gives ipop's speed for the V-search and uses the
  modern solver only for the single final W solve. Existing scripts
  that pass `quadopt = ...` are unchanged: it now sets both
  `quadopt_inner` and `quadopt_outer`.

## First S3 dispatch in the package

* This release introduces S3 method dispatch (`print`, `plot`) for the
  new `synth_inference` and `synth_placebos` classes. Existing
  functions (`synth`, `dataprep`, `path.plot`, `gaps.plot`,
  `synth.tab`, etc.) are unchanged in behavior and signature.

# Synth 1.1-10

## Bug fixes

* `synth()` and `fn.V()`: `quadopt = "LowRankQP"` no longer falls
  through to undefined-variable code. The deprecation message is now
  raised via `stop()` rather than `cat()`, which matches the user's
  expectation that the function fails fast on an unsupported option.

* `dataprep()`: the missing-data warning loop in the X0 (control
  predictors) section now iterates over `nrow(X0)` instead of
  `nrow(X1)`. Previously it covered only the first
  `length(time.predictors.prior)` rows, missing roughly
  `(n_controls - 1) / n_controls` of the cells.

* `synth()`: the error message for `ncol(Z0) < 2` no longer mentions
  "specify only one treated unit" (it is checking for at least two
  control units).

* `path.plot()`: `Ylim` is now padded by a fraction of the data
  range, not by `0.3 * Y.min`. The old formula gave
  `0.7 * Y.min` for negative `Y.min`, which moved the lower bound
  *toward zero* and cropped the bottom of negative-valued series.

## Quiet by default

* `synth()`: messages such as "X1, X0, Z1, Z0 all come directly from
  dataprep object", "searching for synthetic control unit", and the
  final summary block printing `MSPE (LOSS V)` and the solution
  vectors are now gated by `verbose = TRUE`. With the default
  `verbose = FALSE`, `synth()` runs silently. Set `verbose = TRUE`
  to restore the previous chatter.

## Documentation / cleanup (no user-visible change)

* Removed dead commented-out collinearity check in `synth.R`.
* Removed an unreachable `is.vector(X0.scaled)` defensive branch in
  `synth.R` (`ncol(X0) < 2` errors out earlier).
* Several typos fixed in error messages: `"\ Please..."` → `"\n Please..."`,
  `"specificy"` → `"specify"`, `"on time period"` → `"one time period"`,
  `"at least on predictor"` → `"at least one predictor"`,
  `"variabale"` → `"variable"`, `"mispecified"` → `"misspecified"`,
  `"supoorted"` → `"supported"`, `"synthtic"` → `"synthetic"`.
* `synth()` and `fn.V()`: cleaned up the unsupported-`quadopt`
  branch (also clarifies error messages).

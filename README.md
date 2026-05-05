# Synth

[![R-CMD-check](https://github.com/j-hai/Synth/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/j-hai/Synth/actions/workflows/R-CMD-check.yaml)

R implementation of the **synthetic control method** for causal inference in
comparative case studies. Estimates the effect of an intervention on a
single unit (a state, country, firm, etc.) by constructing a *synthetic*
control unit as a weighted combination of comparison units that
approximates the treated unit's pre-intervention trajectory on a set of
predictors. The post-intervention divergence between the treated unit and
its synthetic control is the estimated treatment effect.

The method and this implementation are described in:

> Abadie, A., & Gardeazabal, J. (2003). "The Economic Costs of Conflict: A Case Study of the Basque Country." *American Economic Review*, 93(1), 113–132.
>
> Abadie, A., Diamond, A., & Hainmueller, J. (2010). "Synthetic Control Methods for Comparative Case Studies: Estimating the Effect of California's Tobacco Control Program." *Journal of the American Statistical Association*, 105(490), 493–505.
>
> Abadie, A., Diamond, A., & Hainmueller, J. (2011). "Synth: An R Package for Synthetic Control Methods in Comparative Case Studies." *Journal of Statistical Software*, 42(13), 1–17.
>
> Abadie, A., Diamond, A., & Hainmueller, J. (2014). "Comparative Politics and the Synthetic Control Method." *American Journal of Political Science*, 59(2), 495–510.

## Installation

```r
# From CRAN (stable)
install.packages("Synth")

# Development version from GitHub
# install.packages("remotes")
remotes::install_github("j-hai/Synth")
```

## Quick start

The recommended workflow is `dataprep()` → `synth()` → `synth.tab()` /
`path.plot()` / `gaps.plot()`.

```r
library(Synth)
data(synth.data)

# Build the input matrices from a panel data frame
dataprep.out <- dataprep(
  foo                    = synth.data,
  predictors             = c("X1", "X2", "X3"),
  predictors.op          = "mean",
  dependent              = "Y",
  unit.variable          = "unit.num",
  time.variable          = "year",
  special.predictors     = list(
    list("Y", 1991, "mean"),
    list("Y", 1985, "mean"),
    list("Y", 1980, "mean")
  ),
  treatment.identifier   = 7,
  controls.identifier    = c(29, 2, 13, 17, 32, 38),
  time.predictors.prior  = 1984:1989,
  time.optimize.ssr      = 1984:1990,
  unit.names.variable    = "name",
  time.plot              = 1984:1996
)

# Construct the synthetic control unit
synth.out <- synth(dataprep.out)

# Inspect
synth.tab(synth.res = synth.out, dataprep.res = dataprep.out)

# Plot the treated unit vs. its synthetic control
path.plot(synth.res = synth.out, dataprep.res = dataprep.out)

# Plot the gap (treated − synthetic) over time
gaps.plot(synth.res = synth.out, dataprep.res = dataprep.out)
```

The classic Basque-country example from Abadie & Gardeazabal (2003) is
available via `data(basque)`; see `?basque` and `?dataprep`.

## What's new in 1.2-0

* **`synth_data()`** — one-line ergonomic wrapper around `dataprep()`
  for the common case (panel data frame + treated unit name + treatment
  date). The 12-arg `dataprep()` is still there for advanced cases.
* **`synth_inference()`** — split-conformal (Chernozhukov–Wuthrich–Zhu)
  and parametric Gaussian prediction intervals around the synthetic
  counterfactual. Returns an S3 object with `print()`, `plot()`, and
  `as.data.frame()` methods.
* **`generate_placebos()`, `mspe_test()`, `mspe_plot()`,
  `plot_placebos()`** — full in-space placebo workflow following
  Abadie, Diamond, and Hainmueller (2010). Function names match those
  in the **SCtools** package by design; namespace-qualify if both are
  loaded.
* **Optional alternative QP backends** — `quadopt = "cvxr"` (CVXR + ECOS)
  and `quadopt = "torch"` (Frank-Wolfe simplex LS via the `torch`
  package, GPU/MPS-capable). Inner/outer split via `quadopt_inner` /
  `quadopt_outer` keeps V-search at ipop's speed when only the final W
  needs the modern solver.
* **ggplot2 support** — `autoplot.synth_inference()` and
  `autoplot.synth_placebos()` (when `library(ggplot2)` is attached).
* **Cross-platform parallel placebos** — `parallel = TRUE` does the
  right thing on Windows (PSOCK cluster) and unix-likes (forks).
* **Two vignettes** — `vignette("synth-quickstart")` for a 5-minute
  intro, `vignette("inference")` for the inference deep dive.

### Choosing an inference method

| Question                                                              | Method                              | Function                                     | Package |
|---                                                                    |---                                  |---                                           |---      |
| How surprising is the effect vs. other units?                          | placebo MSPE-ratio rank             | `mspe_test()`                                | Synth   |
| Prediction band around the counterfactual (lightweight)                | split-conformal                     | `synth_inference(method = "conformal")`      | Synth   |
| Prediction band assuming i.i.d. Gaussian residuals                     | parametric                          | `synth_inference(method = "parametric")`     | Synth   |
| Period-varying intervals decomposing in/out-of-sample uncertainty      | CFPT prediction intervals           | `scpi::scpi()`                               | scpi    |
| Multiple / staggered treated units                                     | augmented or generalized SC         | `augsynth`, `gsynth`                         | augsynth, gsynth |
| GPU autodiff implementation of the SC family                           | torch-native SC + synthdid + MC     | `trex.panel`                                 | trex (Python) |

See [`NEWS.md`](NEWS.md) for the full change log.

## What's new in 1.1-10

* `synth(verbose = FALSE)` (the default) is now genuinely silent.
  `verbose = TRUE` restores the previous chatter and adds the MSPE/loss
  summary at the end.
* `quadopt = "LowRankQP"` (long deprecated) now errors fast instead of
  printing a message and crashing in undefined-variable code a few
  lines later.
* `path.plot()` and `gaps.plot()` `Ylim` now pads by a fraction of the
  data range, so plots of negative-valued series are no longer cropped
  at the bottom.
* `dataprep()`: the missing-data warning loop in the X0 (control
  predictors) section now iterates over all rows of X0 (it previously
  only covered the first time period for each control).
* Several typos fixed in error/warning messages.

## License

GPL (>= 2). See `LICENSE.note`.

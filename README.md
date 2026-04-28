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

See [`NEWS.md`](NEWS.md) for the full change log.

## License

GPL (>= 2). See `LICENSE.note`.

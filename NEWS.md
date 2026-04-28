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

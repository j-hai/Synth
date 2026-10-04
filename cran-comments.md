# cran-comments.md

## Submission notes for Synth 1.2-0 (draft)

This file is prepared ahead of the 1.2-0 submission. The items under
"To do before submitting" are still open.

Synth 1.2-0 is a feature release relative to Synth 1.1-10 (on CRAN
since 2026-04-29).

### What's new

* `synth_data()`, a wrapper around `dataprep()` for the common case of
  one treated unit and one treatment date.
* `synth_inference()`: split-conformal and parametric prediction
  intervals around the synthetic counterfactual, with `print()`,
  `plot()`, `as.data.frame()` and `ggplot2::autoplot()` methods.
* `synth_placebos()`, `synth_mspe_test()`, `synth_mspe_plot()`: the
  in-space placebo workflow of Abadie, Diamond, and Hainmueller
  (2010), with the same set of methods.
* Optional alternative QP backends for `synth()` and `fn.V()`:
  `quadopt = "cvxr"` and `quadopt = "torch"`. `CVXR`, `torch` and
  `ggplot2` are in `Suggests:`; there is no new hard dependency.
* New dataset `smoking` and two vignettes.
* Bug fixes in `dataprep()` and `synth.tab()`, listed below because
  they can change output.

### Changes that can alter output for existing code

* `dataprep()` applied `predictors.op` to the treated unit only and
  always used the mean for the control units. The operator is now
  applied to both. Results change only for an operator other than the
  default `"mean"`.
* `dataprep()` labelled control units and periods in the order they
  were supplied, while the data are arranged in ascending order.
  Labels now follow the data, and `synth.tab()` matches unit names to
  weights by unit number. Fitted weights and losses do not change;
  labels, the row order of `names.and.numbers` and the order of
  `tag$controls.identifier` change, and only for input that was not
  already in ascending order.
* `dataprep()` now stops with an explanatory message for a predictor
  operator that cannot be used (for example `"range"`). These calls
  already failed, with an unrelated-looking error.
* `Depends:` is now R (>= 3.6.0); the previous R (>= 2.10) could not
  be met by the code.

With the default settings (`quadopt = "ipop"`, `predictors.op =
"mean"`) and identifiers in ascending order, `dataprep()` and
`synth()` return the same values as 1.1-10. This was checked by
running both versions side by side over a grid of `dataprep()`
configurations on the `synth.data` and `basque` examples.

### Test environments

* Local: macOS (aarch64), R 4.4.2.
* GitHub Actions: macOS-latest (R release), windows-latest (R
  release), ubuntu-latest (R devel, R release, R oldrel-1).

### R CMD check results

* GitHub Actions: Status OK on all five configurations.
* Local, `R CMD check --no-manual --run-donttest` with vignettes
  built: 0 errors, 0 warnings, 1 note. The note is "Package suggested
  but not available for checking: 'CVXR'" (not installed on the local
  machine; the CVXR tests run on GitHub Actions).

### Reverse dependencies

`Synth` has 3 reverse dependencies on CRAN: `MSCMT`, `sccic` and
`SCtools`. They were checked by hand against CRAN Synth 1.1-10 and
against this version, on macOS (aarch64), R 4.4.2; see
`revdep/README.md`. No new problems were found.

* `SCtools` 0.3.3.1 (imports Synth): `R CMD check` gives the same
  result with both versions.
* `sccic` 0.1.1 (suggests Synth): `R CMD check` Status OK with both
  versions.
* `MSCMT` 1.4.4 (suggests Synth): could not be built from source on
  the local machine (no Fortran compiler), so the CRAN binary was
  checked with `--install=skip`; same result with both versions.

None of the three passes a predictor operator other than `"mean"` in
its own code, examples, tests or vignettes. `SCtools` and `MSCMT`
forward a user's operator to `dataprep()`, so their users see the
`predictors.op` change described above when they choose another
operator.

### What we kept stable

* Every function exported by 1.1-10 is still exported (`synth`,
  `dataprep`, `synth.tab`, `path.plot`, `gaps.plot`, `fn.V`,
  `spec.pred.func`, `collect.optimx`). `synth()` and `fn.V()` gain
  optional arguments whose defaults reproduce the 1.1-10 behaviour.
* All return-list field names on `synth()` and `dataprep()` outputs.

### To do before submitting

* Run win-builder (R-devel) and `R CMD check --as-cran` including the
  PDF manual.
* Re-run the reverse dependency checks with `revdepcheck` on a
  machine with a Fortran compiler, so that `MSCMT` is built from
  source.
* Set `Date:` in `DESCRIPTION` to the submission date.
* Remove "(draft)" and this section.

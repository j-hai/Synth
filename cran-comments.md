# cran-comments.md

## Submission notes for Synth 1.1-10

This is a small bug-fix and quality release relative to the previously
published Synth 1.1-9 (2025-09-18).

### What's new

* `synth()` and `fn.V()` now `stop()` (rather than `cat()` + crash) when
  the long-deprecated `quadopt = "LowRankQP"` is supplied. Previously
  the call printed a deprecation message and then failed with an
  uninformative "object 'solution.w' not found" error.
* `synth(verbose = FALSE)` (the default) is now genuinely silent. The
  per-stage progress messages and the final MSPE / solution.v /
  solution.w summary block are now gated by `verbose = TRUE`.
* `dataprep()`: the missing-data warning loop in the X0 (control
  predictors) section now iterates over `nrow(X0)` instead of
  `nrow(X1)`. Previously it covered only the first time period for
  each control.
* `path.plot()`: `Ylim` is now padded by a fraction of the data range,
  not by `0.3 * Y.min`. The old formula moved the lower bound toward
  zero for negative `Y.min`, cropping the bottom of negative-valued
  series.
* `synth()`: error message for `ncol(Z0) < 2` corrected (was a
  copy-paste of the X0 message and incorrectly mentioned "treated
  unit").
* Several typos fixed in error/warning messages.

All changes preserve the byte-for-byte numerical results of 1.1-9 on
well-conditioned problems; verified by an internal regression test
(`dev/02_regression_check.R`) against the frozen 1.1-9 source.

### Test environments

* macOS Tahoe 26.3.1 (local), R 4.5.3
* Planned via win-builder R-devel and r-hub macOS-release on
  submission.

### R CMD check results

`R CMD check --as-cran` is clean locally — Status: OK, 0 NOTEs.

### Reverse dependencies

`Synth` has 3 direct reverse dependencies on CRAN: `MSCMT`, `sccic`,
`SCtools`. We ran `revdepcheck::revdep_check()` comparing Synth
1.1-10 against CRAN baseline 1.1-9; no new problems were introduced.

### What we kept stable

* All exported function names and signatures (`synth`, `dataprep`,
  `synth.tab`, `path.plot`, `gaps.plot`, `fn.V`, `spec.pred.func`,
  `collect.optimx`).
* All return-list field names on `synth()` and `dataprep()` outputs.

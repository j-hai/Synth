# Reverse dependency checks for Synth 1.2-0

These checks were run by hand on 2026-10-04, not with `revdepcheck`.
The previous contents of this directory were `revdepcheck` output for
the 1.1-10 submission (Synth 1.1-9 against 1.1-10, 2026-04-28).

# Platform

|field    |value                          |
|:--------|:------------------------------|
|version  |R version 4.4.2                |
|system   |aarch64, darwin20 (macOS)      |
|date     |2026-10-04                     |

# Dependencies

|package |old    |new   |
|:-------|:------|:-----|
|Synth   |1.1-10 |1.2-0 |

"old" is the CRAN release; "new" is the development version. All
three packages were checked at commit 16febae; SCtools was checked
again at the commit that restored the 1.1-10 argument order of
`synth()`, with the same result. Since the startup message changed,
the new message shows in the example and vignette output of SCtools
and MSCMT.

# Revdeps

|package |version |relation |result with old |result with new |
|:-------|:-------|:--------|:---------------|:---------------|
|SCtools |0.3.3.1 |Imports  |1 warning       |1 warning       |
|sccic   |0.1.1   |Suggests |OK              |OK              |
|MSCMT   |1.4.4   |Suggests |1 note          |1 note          |

## SCtools

`R CMD check --no-manual` on the CRAN source tarball. The check log is
identical with old and new. The one warning is "package 'future' was
built under R version 4.4.3", which comes from the local library and
not from Synth. Its test suite, run with `NOT_CRAN=true`, gives the
same results with both versions.

Earlier development commits of Synth 1.2-0 exported
`generate_placebos`, `mspe_test`, `mspe_plot` and `plot_placebos`,
the names of SCtools functions with different arguments. With those
commits SCtools failed `R CMD check` with two errors (examples and
vignette rebuild), because its examples attach Synth after SCtools.
The Synth functions were renamed and the errors are gone.

## sccic

`R CMD check` on the CRAN source tarball: Status OK with both
versions; examples and test output identical. sccic only loads the
`basque` data from Synth.

## MSCMT

MSCMT could not be built from source on this machine (no Fortran
compiler), so the install step was not exercised. The CRAN binary of 1.4.4
built for R 4.5 (CRAN's R 4.4 binary is still 1.4.1) was checked
under R 4.4.2 with `R CMD check --install=skip`: one note ("information on
.o files is not available") with both versions; examples and vignette
rebuild identical. The code in its vignette that calls Synth
(`dataprep()`, `synth()`, `improveSynth()`) and `mscmt()` on a
`dataprep()` object give the same numbers with both versions.

## Output that differs between old and new

Only what NEWS.md announces: the order and labels of control units
and periods for input given out of ascending order, the control
predictor matrix when `predictors.op` is not `"mean"`, the messages
for operators that cannot be used, and the startup message. No reverse dependency
uses an operator other than `"mean"` in its own code, examples, tests
or vignettes.

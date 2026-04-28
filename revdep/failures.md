# MSCMT (1.4.1)

* Email: <mailto:martin.becker@mx.uni-saarland.de>
* GitHub mirror: <https://github.com/cran/MSCMT>

Run `revdepcheck::revdep_details(, "MSCMT")` for more info

## In both

*   checking whether package ‘MSCMT’ can be installed ... ERROR
     ```
     Installation failed.
     See ‘/Users/jhainmueller/Documents/GitHub/Synth/revdep/checks.noindex/MSCMT/new/MSCMT.Rcheck/00install.out’ for details.
     ```

## Installation

### Devel

```
* installing *source* package ‘MSCMT’ ...
** this is package ‘MSCMT’ version ‘1.4.1’
** package ‘MSCMT’ successfully unpacked and MD5 sums checked
** using staged installation
** libs
using C compiler: ‘Apple clang version 17.0.0 (clang-1700.6.4.2)’
sh: /opt/gfortran/bin/gfortran: No such file or directory
using SDK: ‘MacOSX26.2.sdk’
clang -arch arm64 -std=gnu2x -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG   -I/opt/R/arm64/include    -fPIC  -falign-functions=64 -Wall -g -O2  -c DE.c -o DE.o
clang -arch arm64 -std=gnu2x -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG   -I/opt/R/arm64/include    -fPIC  -falign-functions=64 -Wall -g -O2  -c Helpers.c -o Helpers.o
clang -arch arm64 -std=gnu2x -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG   -I/opt/R/arm64/include    -fPIC  -falign-functions=64 -Wall -g -O2  -c MSCMT.c -o MSCMT.o
/opt/gfortran/bin/gfortran -arch arm64  -fPIC  -Wall -g -O2  -c inverse.f -o inverse.o
make: /opt/gfortran/bin/gfortran: No such file or directory
make: *** [inverse.o] Error 1
ERROR: compilation failed for package ‘MSCMT’
* removing ‘/Users/jhainmueller/Documents/GitHub/Synth/revdep/checks.noindex/MSCMT/new/MSCMT.Rcheck/MSCMT’


```
### CRAN

```
* installing *source* package ‘MSCMT’ ...
** this is package ‘MSCMT’ version ‘1.4.1’
** package ‘MSCMT’ successfully unpacked and MD5 sums checked
** using staged installation
** libs
using C compiler: ‘Apple clang version 17.0.0 (clang-1700.6.4.2)’
sh: /opt/gfortran/bin/gfortran: No such file or directory
using SDK: ‘MacOSX26.2.sdk’
clang -arch arm64 -std=gnu2x -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG   -I/opt/R/arm64/include    -fPIC  -falign-functions=64 -Wall -g -O2  -c DE.c -o DE.o
clang -arch arm64 -std=gnu2x -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG   -I/opt/R/arm64/include    -fPIC  -falign-functions=64 -Wall -g -O2  -c Helpers.c -o Helpers.o
clang -arch arm64 -std=gnu2x -I"/Library/Frameworks/R.framework/Resources/include" -DNDEBUG   -I/opt/R/arm64/include    -fPIC  -falign-functions=64 -Wall -g -O2  -c MSCMT.c -o MSCMT.o
/opt/gfortran/bin/gfortran -arch arm64  -fPIC  -Wall -g -O2  -c inverse.f -o inverse.o
make: /opt/gfortran/bin/gfortran: No such file or directory
make: *** [inverse.o] Error 1
ERROR: compilation failed for package ‘MSCMT’
* removing ‘/Users/jhainmueller/Documents/GitHub/Synth/revdep/checks.noindex/MSCMT/old/MSCMT.Rcheck/MSCMT’


```

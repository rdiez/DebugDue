#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

# Without this line in the top-level Makefile.am:
#   ACLOCAL_AMFLAGS = -I m4
# you get this warning:
#   libtoolize: Consider adding `-I m4' to ACLOCAL_AMFLAGS in Makefile.am.
# However, if we add that line, autoreconf does not work if you don't manually create
# the m4 subdirectory beforehand.
mkdir --parents "m4"

CMD="autoreconf --warnings=all --install"
printf "$CMD\n\n"
eval "$CMD"

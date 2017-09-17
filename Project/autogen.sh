#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

# We could speed automake up by setting AUTOMAKE_JOBS like this:
#  export AUTOMAKE_JOBS="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"
# However, this feature is still marked as experimental in automake's 1.15 manual.

CMD="autoreconf --warnings=all --install"
printf "$CMD\n\n"
eval "$CMD"

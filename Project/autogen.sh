#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -o posix

CMD="autoreconf --warnings=all --install"
printf "$CMD\n\n"
eval "$CMD"

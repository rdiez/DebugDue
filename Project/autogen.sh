#!/bin/bash

# Copyright (C) 2022 R. Diez - see the DebugDue project for licensing information.

set -o errexit
set -o pipefail
set -o nounset

# We could speed automake up by setting AUTOMAKE_JOBS like this:
#   export AUTOMAKE_JOBS="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"
# However, this feature is still marked as experimental in Automake's 1.16.5 manual.

# autoreconf does many things automatically and is probably more robust.
# However, running aclocal etc. separately is faster for this project,
# like 0.9 instead of 2.2 seconds.

if false; then

  CMD="autoreconf --warnings=all --install"
  echo "$CMD"
  echo
  eval "$CMD"

else

  # autoreconf picks up AC_CONFIG_AUX_DIR automatically, but here we need
  # to create the subdirectory ourselves.
  printf -v CMD \
         "mkdir --parents -- %q" \
         "build-aux"
  echo "$CMD"
  echo
  eval "$CMD"

  # Generate 'aclocal.m4' by scanning 'configure.ac'.
  CMD="aclocal --warnings=all"
  echo "$CMD"
  echo
  eval "$CMD"

  # Generate 'configure' from 'configure.ac'.
  CMD="autoconf --warnings=all"
  echo "$CMD"
  echo
  eval "$CMD"

  # Generate 'Makefile.in' from 'Makefile.am'.
  # autoreconf's "--install" translates to "--add-missing --copy" here.
  CMD="automake --warnings=all --add-missing --copy"
  echo "$CMD"
  echo
  eval "$CMD"

fi

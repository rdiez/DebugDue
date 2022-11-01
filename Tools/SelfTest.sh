#!/bin/bash
#
# This script tests the toolchain builder makefile and the DebugDue firmware builder script.
#
# Steps before running this script:
#
# - Companion script SelfTest-InsideRepoCopy.sh decides what parts to build
#   depending on some environment variables. See its source code for more information.
#
# - Manually download the toolchain tarballs from the Internet to their default location
#   by running the toolchain builder makefile for target "download-tarballs-from-internet".
#   You will need to do this for each TARGET_LIBC (newlib and picolibc).
#   You only need to do this again if you change the component version numbers.
#   I did not want to automate the download step in oder to save bandwidth when
#   running this script several times.
#
# - Set environment variable DEBUGDUE_ASF_PATH so that it points to the root of the ASF library.
#   Remember that you need to patch one header file by hand before using it.
#
# Copyright (c) 2013-2022 - R. Diez - Licensed under the GNU AGPLv3.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


# We want all build messages to be in English, regardless of the current operating system language.
export LANG=C

if (( $# != 0 )); then
  abort "Invalid number of command-line arguments."
fi


GIT_REPOSITORY_BASE="$(readlink --canonicalize --verbose -- "..")"

declare -r TOOLS_DIR="$GIT_REPOSITORY_BASE/Tools"


if true; then
  declare -r ROTATE_DIR_SLOT_COUNT="5"
  declare -r OUTPUT_BASE_DIR="$GIT_REPOSITORY_BASE/SelfTestOutput"
else
  # If you run this script often, you may want to place its output in a RAM disk
  # instead of inside the source repository.
  declare -r ROTATE_DIR_SLOT_COUNT="1"
  declare -r OUTPUT_BASE_DIR="$HOME/MyTmpFs/DebugDueSelfTestOutput"
fi

mkdir --parents -- "$OUTPUT_BASE_DIR"

echo "Rotating test output directories..."

ROTATED_DIR="$(perl "$TOOLS_DIR/RotateDir.pl" --slot-count "$ROTATE_DIR_SLOT_COUNT" --dir-name-prefix "DebugDueSelfTest-" --dir-naming-scheme="date" --output-only-new-dir-name "$OUTPUT_BASE_DIR")"

echo "Test output directory rotated. The output directory is:"
echo "  $ROTATED_DIR"


# Copy the whole Git repository somewhere else and build from there.
# This way, you can keep working on the repository while the build runs on the background.
#
# We only copy the files that are checked into Git, so that the build will fail
# if you forgot to check some file in.
#
# We could clone the repository, but then we cannot use this script to test
# small uncommitted changes in the current repository.

declare -r COPY_OF_REPOSITORY="$ROTATED_DIR/CopyOfRepository"

mkdir -- "$COPY_OF_REPOSITORY"

printf -v CMD \
       "git ls-files -z -- . | xargs --null -- cp --parents --target-directory=%q" \
       "$COPY_OF_REPOSITORY"

pushd "$GIT_REPOSITORY_BASE" >/dev/null

echo
echo "Copying the Git repository..."
echo "$CMD"
eval "$CMD"

popd >/dev/null


# About option '--link': Use hard links to prevent copying big files around.
#                        The user will probably not be modifying the downloaded tarballs.

echo
echo "Copying all tarballs..."

mkdir -- "$ROTATED_DIR/TarballsSource"

printf -v CMD \
       "cp --recursive --link -- %q/* %q/" \
       "$GIT_REPOSITORY_BASE/Toolchain/Tarballs" \
       "$ROTATED_DIR/TarballsSource"

echo "$CMD"
eval "$CMD"

echo
echo "Starting the self-test inside the copy of the repository..."

exec -- "$COPY_OF_REPOSITORY/Tools/SelfTest-InsideRepoCopy.sh" "$ROTATED_DIR"

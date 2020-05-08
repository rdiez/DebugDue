#!/bin/bash
#
# This scripts tests the toolchain builder makefile and the JtagDue firmware builder script.
#
# Steps before running this script:
#
# - Edit variable ASF_PATH in this script, so that it points to the root of the ASF library.
#   Remember that you need to patch one header file by hand before using it.
#
# - Manually download the toolchain tarballs from the Internet to their default location
#   by running the toolchain builder makefile for target "download-tarballs-from-internet".
#   You only need to do this again if you change the component version numbers.
#   I did not want to automate the download step in oder to save bandwidth when
#   running this script several times.
#
# Copyright (c) 2013-2018 - R. Diez - Licensed under the GNU AGPLv3.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


run_cmd ()
{
  # $1: Description banner.
  # $2: Command to run.
  # $3: Log file.
  # $4: Redirection type.

  echo
  echo "$1"

  echo "$2"

  set +o errexit

  case "$4" in

    noredir)  eval "$2";;

    # Some commands should not generate any stderr output. We could check whether stderr is empty.
    # At the moment, we just leave any stderr appear on the main build log,
    # where it will probably be noticed.
    stdout)  eval "$2" >"$3";;

    both)  eval "$2" >"$3"  2>&1;;

    *) abort "Invalid redirection type of \"$4\".";;

  esac

  CMD_EXIT_CODE="$?"
  set -o errexit

  if (( CMD_EXIT_CODE != 0 )); then
    abort "Command failed with exit code $CMD_EXIT_CODE. The log file is: $3";
  fi
}


# ----- Entry point -----

TOOLS_DIR="$(readlink --canonicalize --verbose -- ".")"
GIT_REPOSITORY_BASE="$(readlink --canonicalize --verbose -- "..")"
declare -r TOOLCHAIN_DIR="$GIT_REPOSITORY_BASE/Toolchain"

if [ $# -ne 0 ]; then
  abort "Invalid number of command-line arguments."
fi


if true; then
  declare -r ROTATE_DIR_SLOT_COUNT="5"
  declare -r OUTPUT_BASE_DIR="$GIT_REPOSITORY_BASE/SelfTestOutput"
else
  # If you run this script often, you may want to place its output in a RAM disk
  # instead of inside the source repository.
  declare -r ROTATE_DIR_SLOT_COUNT="1"
  declare -r OUTPUT_BASE_DIR="$HOME/MyTmpFs/JtagDueSelfTestOutput"
fi

mkdir --parents -- "$OUTPUT_BASE_DIR"

echo "Rotating test output directory..."

ROTATED_DIR="$(perl "$TOOLS_DIR/RotateDir.pl" --slot-count "$ROTATE_DIR_SLOT_COUNT" --dir-name-prefix "ToolchainMakefileTest-" --dir-naming-scheme="date" --output-only-new-dir-name "$OUTPUT_BASE_DIR")"

echo "Test output directory rotated. The output directory is:"
echo "  $ROTATED_DIR"


# Copy the whole Toolchain/ directory, as checked into the Git repository, to another place,
# in order to run the makefile from there. The reason why we are doing this is that
# we want to make sure the Toolchain/ directory contains everything you need to
# build a toolchain. And we also want to fail the test if we have forgotten to check something
# in the repository.

declare -r COPY_OF_TOOLCHAIN_DIRNAME="$ROTATED_DIR/CopyOfToolchainDir"
declare -r DOWNLOADED_TARBALLS_DIRNAME="$ROTATED_DIR/DownloadedTarballs"

mkdir -- "$COPY_OF_TOOLCHAIN_DIRNAME"

printf -v CMD  "git ls-files -z -- . | xargs --null -- cp --parents --target-directory=%q"  "$COPY_OF_TOOLCHAIN_DIRNAME"

pushd "$TOOLCHAIN_DIR" >/dev/null
run_cmd "Copying the checked-in toolchain makefile files to a separate directory..."  "$CMD"  ""  "noredir"
popd  >/dev/null


pushd "$COPY_OF_TOOLCHAIN_DIRNAME" >/dev/null

# Option '--warn-undefined-variables' is no longer necessary below, because the makefile sets this itself.
declare -r USUAL_ARGS="--no-builtin-variables"

PARALLEL_COUNT="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"

# Option '--output-sync=recurse' is no longer necessary below, because the makefile sets this itself.
declare -r PARALLEL_ARGS="-j $PARALLEL_COUNT"


# Running make without arguments should just display the help text.
# It should not attempt to do anything else and fail.

run_cmd "Testing running 'make' with no arguments..." "make" "$ROTATED_DIR/toolchain-make-no-targets.txt"  stdout

printf -v CMD "make %s"  "$USUAL_ARGS"
run_cmd "Testing running 'make' with the usual arguments and no targets..."  "$CMD"  "$ROTATED_DIR/toolchain-make-usual-no-targets.txt"  stdout

# Check that "make help" does not fail.
run_cmd "Testing 'make help' with no arguments..." "make help" "$ROTATED_DIR/toolchain-make-help.txt"  stdout

printf -v CMD "make %s  help"  "$USUAL_ARGS"
run_cmd "Testing 'make help' with the usual arguments..."  "$CMD" "$ROTATED_DIR/toolchain-make-usual-help.txt"  stdout

# Check that "make test-makeflags" works.
printf -v CMD "make %s  %s  test-makeflags"  "$USUAL_ARGS"  "$PARALLEL_ARGS"
run_cmd "Testing 'make test-makeflags'..." "$CMD" "$ROTATED_DIR/toolchain-make-test-makeflags.txt"  stdout

run_cmd "Testing 'make clean' with nothing to clean..."  "make clean"  "$ROTATED_DIR/toolchain-make-clean.txt"  stdout

printf -v CMD "make %s  clean"  "$USUAL_ARGS"
run_cmd "Testing 'make clean' with nothing to clean and the usual arguments..."  "$CMD" "$ROTATED_DIR/toolchain-make-usual-clean.txt"  stdout

declare -r SKIP_TOOLCHAIN_TARBALL_DOWNLOADS=false

if ! $SKIP_TOOLCHAIN_TARBALL_DOWNLOADS; then

  printf -v CMD \
         "make %s  TARBALLS_DOWNLOAD_DIR=%q  PATH_TO_TARBALLS_ON_FILE_SERVER=%q  download-tarballs-from-file-server" \
         "$USUAL_ARGS" \
         "$DOWNLOADED_TARBALLS_DIRNAME" \
         "$TOOLCHAIN_DIR/Tarballs"

  run_cmd "Testing downloading tarballs from a file server to a different directory..."  "$CMD"  "$ROTATED_DIR/toolchain-make-download-to-specific-dir.txt" both


  printf -v CMD \
         "make %s  PATH_TO_TARBALLS_ON_FILE_SERVER=%q  download-tarballs-from-file-server" \
         "$USUAL_ARGS" \
         "$TOOLCHAIN_DIR/Tarballs"

  run_cmd "Testing downloading tarballs from a file server to the default directory..."  "$CMD"  "$ROTATED_DIR/toolchain-make-download-to-default-dir.txt" both

fi


declare -r BUILD_DIR="$ROTATED_DIR/build"
declare -r INSTALLATION_DIR="$ROTATED_DIR/bin"

declare -r SKIP_TOOLCHAIN_BUILD=false

if $SKIP_TOOLCHAIN_BUILD; then

  TOOLCHAIN_BIN_DIR="$OUTPUT_BASE_DIR/CurrentToolchain/bin"
  # TOOLCHAIN_BIN_DIR="$HOME/some-other-toolchain-when-testing-this-script"

else

  printf -v CMD  "make %s  %s  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  all" \
       "$USUAL_ARGS" \
       "$PARALLEL_ARGS" \
       "$INSTALLATION_DIR" \
       "$BUILD_DIR"

  run_cmd "Testing building the toolchain..."  "$CMD"  "$ROTATED_DIR/toolchain-make-build-all.txt"  both


  # LANG="C" is to make sure that the tools print messages in English,
  # because we will be searching for an English text later on in the output.
  CMD="LANG=\"C\"  $CMD"

  run_cmd "Testing running the toolchain building makefile a second time..."  "$CMD"  "$ROTATED_DIR/toolchain-make-build-all-2.txt"  both

  OUTPUT_FILE_CONTENTS=$(<"$ROTATED_DIR/toolchain-make-build-all-2.txt")

  declare -r NOTHING_TO_DO_REGEX=".*Nothing to be done for.*"

  if ! [[ $OUTPUT_FILE_CONTENTS =~ $NOTHING_TO_DO_REGEX ]]; then
    abort "Trying to run the makefile as second time still finds something to be built."
  fi

  TOOLCHAIN_BIN_DIR="$INSTALLATION_DIR"

fi


declare -r SKIP_TOOLCHAIN_CHECK=false

if ! $SKIP_TOOLCHAIN_CHECK; then

  printf -v CMD  "make %s  %s  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  check" \
       "$USUAL_ARGS" \
       "$PARALLEL_ARGS" \
       "$INSTALLATION_DIR" \
       "$BUILD_DIR"

  run_cmd "Checking the toolchain..."  "$CMD"  "$ROTATED_DIR/toolchain-make-check.txt"  both

fi


popd >/dev/null


# Copy all checked-in files to another place, and build the JtagDue firmware from there.
# This way, we makesure that we have not forgotten to check some file in.
#
# We could clone the repository, but then we cannot use this test script to test
# small uncommitted changes in the current repository.

declare -r COPY_OF_REPOSITORY="$ROTATED_DIR/CopyOfRepository"

mkdir -- "$COPY_OF_REPOSITORY"

printf -v CMD "git ls-files -z -- . | xargs --null -- cp --parents --target-directory=%q"  "$COPY_OF_REPOSITORY"

pushd "$GIT_REPOSITORY_BASE" >/dev/null
run_cmd  "Copy all checked-in repository files to another directory..."  "$CMD"  ""  "noredir"
popd >/dev/null

printf -v CMD "%q --help"  "$COPY_OF_REPOSITORY/JtagDueBuilder.sh"
run_cmd "Testing the JtagDue builder script with --help ..."  "$CMD"  "$ROTATED_DIR/JtagDueBuilder-output-help.txt"  stdout

if false; then

  # Unfortunately, we cannot unpack the ASF automatically, because you need to patch it manually before using it.

  PATH_TO_ASF_TARBALL="$HOME/path/to/xdk-asf-3.xx.x.zip"

  declare -r ASF_UNPACK_BASEDIR="$ROTATED_DIR/AsfUnpacked"

  printf -v CMD  "unzip -q -d %q  %q"  "$ASF_UNPACK_BASEDIR"  "$PATH_TO_ASF_TARBALL"
  run_cmd  "Unpacking the ASF..."  "$CMD"  ""  "noredir"


  # Find the ASF root. The "_*" rule skips weird directory names like "__MACOSX".

  echo
  echo "Finding the ASF root dir..."

  printf -v CMD  "find  %q  -type d  -name '_*' -prune  -o -path '*/sam/drivers' -print"  "$ASF_UNPACK_BASEDIR"
  echo "$CMD"
  DIR_MATCH="$(eval "$CMD")"

  # echo "DIR_MATCH: $DIR_MATCH"

  ASF_PATH="$(readlink --canonicalize --verbose -- "$DIR_MATCH/../..")"

else

  ASF_PATH="$HOME/path/to/xdk-asf-x.xx.x"

fi


pushd "$COPY_OF_REPOSITORY" >/dev/null


printf -v BUILD_BASE_CMD "%q  --toolchain-dir=%q"  "$COPY_OF_REPOSITORY/JtagDueBuilder.sh"  "$TOOLCHAIN_BIN_DIR"

printf -v BUILD_BASE_ASF_CMD "%s  --atmel-software-framework=%q"  "$BUILD_BASE_CMD"  "$ASF_PATH"

run_cmd "Building JtagDue, debug build..."  "$BUILD_BASE_ASF_CMD  --build-type=debug --build"  "$ROTATED_DIR/JtagDueBuilder-JtagDue-debug.txt" both

run_cmd "Building JtagDue, debug build with disassemble..."  "$BUILD_BASE_ASF_CMD  --build-type=debug --build --disassemble"  "$ROTATED_DIR/JtagDueBuilder-JtagDue-debug-disassemble.txt"  both

run_cmd "Building JtagDue, release build..."  "$BUILD_BASE_ASF_CMD  --build-type=release --build"  "$ROTATED_DIR/JtagDueBuilder-JtagDue-release.txt" both

run_cmd "Building EmptyFirmware, debug build..."  "$BUILD_BASE_ASF_CMD  --project=EmptyFirmware --build-type=debug --build"  "$ROTATED_DIR/JtagDueBuilder-EmptyFirmware-debug.txt"  both

run_cmd "Building EmptyFirmware, release build..."  "$BUILD_BASE_ASF_CMD  --project=EmptyFirmware --build-type=release --build"  "$ROTATED_DIR/JtagDueBuilder-EmptyFirmware-release.txt"  both

run_cmd "Building QemuFirmware, debug build..."  "$BUILD_BASE_CMD  --project=QemuFirmware --build-type=debug --build"  "$ROTATED_DIR/JtagDueBuilder-QemuFirmware-debug.txt"  both

run_cmd "Building QemuFirmware, release build..."  "$BUILD_BASE_CMD  --project=QemuFirmware --build-type=release --build"  "$ROTATED_DIR/JtagDueBuilder-QemuFirmware-release.txt"  both

popd >/dev/null

echo
echo "All self-tests finished."

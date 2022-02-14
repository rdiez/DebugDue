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


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
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


set_make_parallel_jobs_flag ()
{
  local SHOULD_ADD_PARALLEL_FLAG=true

  if is_var_set "MAKEFLAGS"
  then

    if false; then
      echo "MAKEFLAGS: $MAKEFLAGS"
    fi

    # The following string search is not 100 % watertight, as MAKEFLAGS can have further arguments at the end like " -- VAR1=VALUE1 VAR2=VALUE2 ...".
    if [[ $MAKEFLAGS =~ --jobserver-fds= || $MAKEFLAGS =~ --jobserver-auth= ]]
    then
      # echo "Called from a makefile with parallel jobs enabled."
      SHOULD_ADD_PARALLEL_FLAG=false
    fi
  fi

  if $SHOULD_ADD_PARALLEL_FLAG; then
    # This is probably not the best heuristic for make -j , but it's better than nothing.
    PARALLEL_COUNT="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"
    PARALLEL_ARGS="-j $PARALLEL_COUNT  --output-sync=recurse"
  else
    PARALLEL_ARGS=""
  fi
}


# ----- Entry point -----

declare -r VERSION_SET_FOR_PICOBLIC="VersionSet9Picolibc"

declare -r SKIP_TOOLCHAIN_TARBALL_DOWNLOADS_NEWLIB=false
declare -r SKIP_TOOLCHAIN_TARBALL_DOWNLOADS_PICOLIBC=false
declare -r SKIP_TOOLCHAIN_BUILD_NEWLIB=false
declare -r SKIP_TOOLCHAIN_CHECK_NEWLIB=false
declare -r SKIP_TOOLCHAIN_BUILD_WITHOUT_GMP_MPFR_MPC=false
declare -r SKIP_TOOLCHAIN_BUILD_PICOLIBC=false

# We want all build messages to be in English, regardless of the current operating system language.
export LANG=C

TOOLS_DIR="$(readlink --canonicalize --verbose -- ".")"
GIT_REPOSITORY_BASE="$(readlink --canonicalize --verbose -- "..")"
declare -r TOOLCHAIN_DIR="$GIT_REPOSITORY_BASE/Toolchain"

if (( $# != 0 )); then
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
declare -r LOG_FILES_DIRNAME="$ROTATED_DIR/Logs"

mkdir -- "$COPY_OF_TOOLCHAIN_DIRNAME"
mkdir -- "$LOG_FILES_DIRNAME"

printf -v CMD  "git ls-files -z -- . | xargs --null -- cp --parents --target-directory=%q"  "$COPY_OF_TOOLCHAIN_DIRNAME"

pushd "$TOOLCHAIN_DIR" >/dev/null
run_cmd "Copying the checked-in toolchain makefile files to a separate directory..."  "$CMD"  ""  "noredir"
popd  >/dev/null


pushd "$COPY_OF_TOOLCHAIN_DIRNAME" >/dev/null

# Option '--warn-undefined-variables' is no longer necessary below, because the makefile sets this itself.
declare -r USUAL_ARGS="--no-builtin-variables"

set_make_parallel_jobs_flag


# Running make without arguments should just display the help text.
# It should not attempt to do anything else and fail.

run_cmd "Testing running 'make' with no arguments..." "make" "$LOG_FILES_DIRNAME/toolchain-make-no-targets.txt"  stdout

printf -v CMD "make %s"  "$USUAL_ARGS"
run_cmd "Testing running 'make' with the usual arguments and no targets..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-usual-no-targets.txt"  stdout

# Check that "make help" does not fail.
run_cmd "Testing 'make help' with no arguments..." "make help" "$LOG_FILES_DIRNAME/toolchain-make-help.txt"  stdout

printf -v CMD "make %s  help"  "$USUAL_ARGS"
run_cmd "Testing 'make help' with the usual arguments..."  "$CMD" "$LOG_FILES_DIRNAME/toolchain-make-usual-help.txt"  stdout

# Check that "make test-makeflags" works.
printf -v CMD "make %s  %s  test-makeflags"  "$USUAL_ARGS"  "$PARALLEL_ARGS"
run_cmd "Testing 'make test-makeflags'..." "$CMD" "$LOG_FILES_DIRNAME/toolchain-make-test-makeflags.txt"  stdout

run_cmd "Testing 'make clean' with nothing to clean..."  "make clean"  "$LOG_FILES_DIRNAME/toolchain-make-clean.txt"  stdout

printf -v CMD "make %s  clean"  "$USUAL_ARGS"
run_cmd "Testing 'make clean' with nothing to clean and the usual arguments..."  "$CMD" "$LOG_FILES_DIRNAME/toolchain-make-usual-clean.txt"  stdout

if ! $SKIP_TOOLCHAIN_TARBALL_DOWNLOADS_NEWLIB; then

  printf -v CMD \
         "make %s  TARBALLS_DOWNLOAD_DIR=%q  PATH_TO_TARBALLS_ON_FILE_SERVER=%q  download-tarballs-from-file-server" \
         "$USUAL_ARGS" \
         "$DOWNLOADED_TARBALLS_DIRNAME" \
         "$TOOLCHAIN_DIR/Tarballs"

  run_cmd "Testing downloading tarballs with Newlib from a file server to a different directory..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-download-newlib-to-specific-dir.txt" both


  # These are the tarballs that will be used when building the toolchain.

  printf -v CMD \
         "make %s  PATH_TO_TARBALLS_ON_FILE_SERVER=%q  download-tarballs-from-file-server" \
         "$USUAL_ARGS" \
         "$TOOLCHAIN_DIR/Tarballs"

  run_cmd "Testing downloading tarballs with Newlib from a file server to the default directory..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-download-newlib-to-default-dir.txt" both

fi

if ! $SKIP_TOOLCHAIN_TARBALL_DOWNLOADS_PICOLIBC; then


  printf -v CMD \
         "make %s  PATH_TO_TARBALLS_ON_FILE_SERVER=%q  VERSION_SET=%q  download-tarballs-from-file-server" \
         "$USUAL_ARGS" \
         "$TOOLCHAIN_DIR/Tarballs" \
         "$VERSION_SET_FOR_PICOBLIC"

  run_cmd "Testing downloading tarballs with Picolibc from a file server to the default directory..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-download-picolibc-to-default-dir.txt" both

fi


declare -r BUILD_DIR="$ROTATED_DIR/Toolchain-Build"
declare -r BUILD_DIR_PICOLIBC="$ROTATED_DIR/Toolchain-Picolibc-Build"
declare -r BUILD_DIR_WITHOUT_GMP_MPFR_MPC="$ROTATED_DIR/Toolchain-WithoutGmpMpfrMpc-Build"
declare -r INSTALLATION_DIR="$ROTATED_DIR/Toolchain-Bin"
declare -r INSTALLATION_DIR_PICOLIBC="$ROTATED_DIR/Toolchain-Picolibc-Bin"
declare -r INSTALLATION_DIR_WITHOUT_GMP_MPFR_MPC="$ROTATED_DIR/Toolchain-WithoutGmpMpfrMpc-Bin"

TOOLCHAIN_BIN_DIR=""

if ! $SKIP_TOOLCHAIN_BUILD_NEWLIB; then

  printf -v CMD  "make %s  %s  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  all" \
       "$USUAL_ARGS" \
       "$PARALLEL_ARGS" \
       "$INSTALLATION_DIR" \
       "$BUILD_DIR"

  run_cmd "Testing building the toolchain..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-build-all-newlib.txt"  both


  # If environment variable LANG="C" were not set beforehand, we would need to do it here,
  # because we will be searching for an English text later on in the output.
  #   CMD="LANG=\"C\"  $CMD"

  run_cmd "Testing running the toolchain building makefile a second time..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-build-all-newlib-2.txt"  both

  OUTPUT_FILE_CONTENTS=$(<"$LOG_FILES_DIRNAME/toolchain-make-build-all-newlib-2.txt")

  declare -r NOTHING_TO_DO_REGEX=".*Nothing to be done for.*"

  if ! [[ $OUTPUT_FILE_CONTENTS =~ $NOTHING_TO_DO_REGEX ]]; then
    abort "Trying to run the makefile as second time still finds something to be built."
  fi

  if [ -z "$TOOLCHAIN_BIN_DIR" ]; then
    TOOLCHAIN_BIN_DIR="$INSTALLATION_DIR"
  fi

fi


if ! $SKIP_TOOLCHAIN_CHECK_NEWLIB; then

  printf -v CMD  "make %s  %s  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  check" \
       "$USUAL_ARGS" \
       "$PARALLEL_ARGS" \
       "$INSTALLATION_DIR" \
       "$BUILD_DIR"

  run_cmd "Checking the toolchain..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-check.txt"  both

fi


if ! $SKIP_TOOLCHAIN_BUILD_WITHOUT_GMP_MPFR_MPC; then

  printf -v CMD  "make %s  %s  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  BUILD_GMP_MPFR_MPC=0  all" \
       "$USUAL_ARGS" \
       "$PARALLEL_ARGS" \
       "$INSTALLATION_DIR_WITHOUT_GMP_MPFR_MPC" \
       "$BUILD_DIR_WITHOUT_GMP_MPFR_MPC"

  run_cmd "Testing building the toolchain without GMP, MPFR and MPC..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-build-all-without-gmp-mpfr-mpc.txt"  both

  if [ -z "$TOOLCHAIN_BIN_DIR" ]; then
    TOOLCHAIN_BIN_DIR="$INSTALLATION_DIR_WITHOUT_GMP_MPFR_MPC"
  fi
fi


if ! $SKIP_TOOLCHAIN_BUILD_PICOLIBC; then

  printf -v CMD  "make %s  %s  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  VERSION_SET=%q  all" \
       "$USUAL_ARGS" \
       "$PARALLEL_ARGS" \
       "$INSTALLATION_DIR_PICOLIBC" \
       "$BUILD_DIR_PICOLIBC" \
       "$VERSION_SET_FOR_PICOBLIC"

  run_cmd "Testing building the toolchain with Picolibc..."  "$CMD"  "$LOG_FILES_DIRNAME/toolchain-make-build-all-picolibc.txt"  both

  if [ -z "$TOOLCHAIN_BIN_DIR" ]; then
    TOOLCHAIN_BIN_DIR="$INSTALLATION_DIR_PICOLIBC"
  fi

fi


if [ -z "$TOOLCHAIN_BIN_DIR" ]; then

  # If we are not building a new toolchain, use whatever toolchain we have been using.
  TOOLCHAIN_BIN_DIR="$OUTPUT_BASE_DIR/CurrentToolchain"
  # Otherwise, specify your own like this:
  #   TOOLCHAIN_BIN_DIR="$HOME/some-other-toolchain-when-testing-this-script"
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
run_cmd "Testing the JtagDue builder script with --help ..."  "$CMD"  "$LOG_FILES_DIRNAME/JtagDueBuilder-output-help.txt"  stdout

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

elif is_var_set "ASF_PATH"; then

  :  # We have got ASF_PATH from the environment, so there is nothing to do here.

else

  abort "Set the ASF_PATH variable below, and the comment out this 'abort' line. Alternatively, pass ASF_PATH as an environment variable."

  ASF_PATH="$HOME/path/to/xdk-asf-x.xx.x"

fi


pushd "$COPY_OF_REPOSITORY" >/dev/null

# About option '--show-build-commands': Sometimes it is useful to look at the compiler flags used when building the projects.

printf -v BUILD_BASE_CMD "%q  --show-build-commands  --toolchain-dir=%q"  "$COPY_OF_REPOSITORY/JtagDueBuilder.sh"  "$TOOLCHAIN_BIN_DIR"

printf -v BUILD_BASE_ASF_CMD "%s  --atmel-software-framework=%q"  "$BUILD_BASE_CMD"  "$ASF_PATH"

run_cmd "Building JtagDue, debug build..."  "$BUILD_BASE_ASF_CMD  --build-type=debug --build"  "$LOG_FILES_DIRNAME/JtagDueBuilder-JtagDue-debug.txt" both

run_cmd "Building JtagDue, debug build with disassemble..."  "$BUILD_BASE_ASF_CMD  --build-type=debug --build --disassemble"  "$LOG_FILES_DIRNAME/JtagDueBuilder-JtagDue-debug-disassemble.txt"  both

run_cmd "Building JtagDue, release build..."  "$BUILD_BASE_ASF_CMD  --build-type=release --build"  "$LOG_FILES_DIRNAME/JtagDueBuilder-JtagDue-release.txt" both

run_cmd "Building EmptyFirmware, debug build..."  "$BUILD_BASE_ASF_CMD  --project=EmptyFirmware --build-type=debug --build"  "$LOG_FILES_DIRNAME/JtagDueBuilder-EmptyFirmware-debug.txt"  both

run_cmd "Building EmptyFirmware, release build..."  "$BUILD_BASE_ASF_CMD  --project=EmptyFirmware --build-type=release --build"  "$LOG_FILES_DIRNAME/JtagDueBuilder-EmptyFirmware-release.txt"  both

run_cmd "Building QemuFirmware, debug build..."  "$BUILD_BASE_CMD  --project=QemuFirmware --build-type=debug --build"  "$LOG_FILES_DIRNAME/JtagDueBuilder-QemuFirmware-debug.txt"  both

run_cmd "Building QemuFirmware, release build..."  "$BUILD_BASE_CMD  --project=QemuFirmware --build-type=release --build"  "$LOG_FILES_DIRNAME/JtagDueBuilder-QemuFirmware-release.txt"  both

popd >/dev/null

echo
echo "All self-tests finished."

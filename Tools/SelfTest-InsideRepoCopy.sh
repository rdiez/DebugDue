#!/bin/bash
#
# See companion script SelfTest.sh for more information.
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


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


run_cmd ()
{
  local -r L_DESCRIPTION_BANNER="$1"
  local -r L_CMD="$2"
  local -r L_REDIRECTION_TYPE="$3"
  local -r L_LOG_FILENAME="$4"

  echo
  echo "$L_DESCRIPTION_BANNER"

  echo "$L_CMD"

  local -r RUN_AND_REPORT_TOOL_PATH="$COPY_OF_REPOSITORY/Toolchain/Tools/RunAndReport.sh"

  case "$L_REDIRECTION_TYPE" in

    # We are not using 'noredir' anymore.
    noredir)
      if [ -n "$L_LOG_FILENAME" ]; then
        abort "A log filename has been specified, but no output redirection has been requested."
      fi

      local -r LOG_FILE_HINT_SUFFIX=""
      ;;

    stdout|both)
      if [ -z "$L_LOG_FILENAME" ]; then
        abort "An output redirection has been requested, but no log filename has been specified."
      fi

      local -r LOG_FILE_HINT_SUFFIX=" The log file is: $L_LOG_FILENAME"
      ;;

    *) abort "Invalid redirection type of \"$L_REDIRECTION_TYPE\".";;

  esac

  case "$L_REDIRECTION_TYPE" in

    noredir)
      # If you want to use this option, you should probably change the way the command is run below.
      abort "We are not using 'noredir' anymore."
      set +o errexit
      eval "$L_CMD"
      local -r L_CMD_EXIT_CODE="$?"
      set -o errexit
      ;;


    # Use this option for commands that should not write anything to stderr.
    # This is to prevent warnings from 'make' etc. going unnoticed.
    stdout)

      local STDERR_COPY_FILENAME="$L_LOG_FILENAME.stderr"

      set +o errexit
      "$RUN_AND_REPORT_TOOL_PATH" --quiet --copy-stderr="$STDERR_COPY_FILENAME" -- \
                                  "$L_DESCRIPTION_BANNER" "$L_DESCRIPTION_BANNER" "$L_LOG_FILENAME" /dev/null \
                                  bash -c "$L_CMD"
      local -r L_CMD_EXIT_CODE="$?"
      set -o errexit
      ;;

    both)

      set +o errexit

      "$RUN_AND_REPORT_TOOL_PATH" --quiet -- \
                                  "$L_DESCRIPTION_BANNER" "$L_DESCRIPTION_BANNER" "$L_LOG_FILENAME" /dev/null \
                                  bash -c "$L_CMD"

      local -r L_CMD_EXIT_CODE="$?"
      set -o errexit
      ;;

    *) abort "Invalid redirection type of \"$L_REDIRECTION_TYPE\".";;

  esac

  if (( L_CMD_EXIT_CODE != 0 )); then
    abort "Command failed with exit code $L_CMD_EXIT_CODE.$LOG_FILE_HINT_SUFFIX";
  fi

  if [[ "$L_REDIRECTION_TYPE" = "stdout" ]]; then

    if ! [ -f "$STDERR_COPY_FILENAME" ]; then
      abort "File $STDERR_COPY_FILENAME does not exist."
    fi

    if [ -s "$STDERR_COPY_FILENAME" ]; then
      abort "File \"$STDERR_COPY_FILENAME\" is not empty, so the command generated warnings or errors."
    fi

    rm -- "$STDERR_COPY_FILENAME"

  fi
}


get_make_parallel_args ()
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


test_basic_functions_of_toolchain_makefile ()
{
  echo
  echo "Testing the basic functions of the toolchain makefile..."

  local L_CMD

  # Running make without arguments should just display the help text.
  # It should not attempt to do anything else and fail.
  run_cmd "Testing running 'make' with no arguments..." \
          "make" \
          stdout  "$LOG_FILES_DIRNAME/toolchain-make-no-targets.txt"


  printf -v L_CMD \
         "make %s" \
         "$USUAL_MAKE_ARGS"

  run_cmd "Testing running 'make' with the usual arguments and no targets..." \
          "$L_CMD" \
          stdout  "$LOG_FILES_DIRNAME/toolchain-make-usual-no-targets.txt"


  # Check that "make help" does not fail.
  run_cmd "Testing 'make help' with no arguments..." \
          "make help" \
          stdout  "$LOG_FILES_DIRNAME/toolchain-make-help.txt"


  printf -v L_CMD \
         "make %s  help" \
         "$USUAL_MAKE_ARGS"

  run_cmd "Testing 'make help' with the usual arguments..." \
          "$L_CMD" \
          stdout  "$LOG_FILES_DIRNAME/toolchain-make-usual-help.txt"


  # Check that "make test-makeflags" works.
  printf -v L_CMD \
         "make %s  %s  test-makeflags" \
         "$USUAL_MAKE_ARGS" \
         "$PARALLEL_ARGS"

  run_cmd "Testing 'make test-makeflags'..." \
          "$L_CMD" \
          stdout  "$LOG_FILES_DIRNAME/toolchain-make-test-makeflags.txt"


  run_cmd "Testing 'make clean' with nothing to clean..." \
          "make clean" \
          stdout  "$LOG_FILES_DIRNAME/toolchain-make-clean.txt"


  printf -v L_CMD \
         "make %s  clean" \
         "$USUAL_MAKE_ARGS"

  run_cmd "Testing 'make clean' with nothing to clean and the usual arguments..." \
          "$L_CMD" \
          stdout  "$LOG_FILES_DIRNAME/toolchain-make-usual-clean.txt"
}


test_building_toolchain ()
{
  local -r L_LIBC_NAME="$1"

  echo "Toolchain build tests for $L_LIBC_NAME"

  local L_CMD

  local -r SHOULD_SKIP_TARBALL_DOWNLOAD_TEST="${DEBUGDUE_SKIP_TARBALL_DOWNLOAD_TEST:-false}"

  if $SHOULD_SKIP_TARBALL_DOWNLOAD_TEST; then

    local -r DOWNLOADED_TARBALLS_DIRNAME="$ROTATED_DIR/TarballsSource"

  else

    local -r DOWNLOADED_TARBALLS_DIRNAME="$ROTATED_DIR/$L_LIBC_NAME/DownloadedTarballs"

    printf -v L_CMD \
           "make %s  TARGET_LIBC=%q  TARBALLS_DOWNLOAD_DIR=%q  PATH_TO_TARBALLS_ON_FILE_SERVER=%q  download-tarballs-from-file-server" \
           "$USUAL_MAKE_ARGS" \
           "$L_LIBC_NAME" \
           "$DOWNLOADED_TARBALLS_DIRNAME" \
           "$ROTATED_DIR/TarballsSource"

    run_cmd "Testing downloading tarballs from a file server to a different directory..." \
            "$L_CMD" \
            stdout  "$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-download-to-specific-dir.txt"

    # The default download directory will accumulate the tarballs for both Newlib and Picolibc,
    # so we will not be using it later on to build the toolchain.

    printf -v L_CMD \
           "make %s  TARGET_LIBC=%q  PATH_TO_TARBALLS_ON_FILE_SERVER=%q  download-tarballs-from-file-server" \
           "$USUAL_MAKE_ARGS" \
           "$L_LIBC_NAME" \
           "$ROTATED_DIR/TarballsSource"

    run_cmd "Testing downloading tarballs from a file server to the default directory..." \
            "$L_CMD" \
            stdout \
            "$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-download-to-default-dir.txt"
  fi


  local -r SHOULD_SKIP_TOOLCHAIN_CHECK="${DEBUGDUE_SKIP_TOOLCHAIN_CHECK:-true}"


  # This will be the toolchain to use later on to build the firmwares.
  # If we build both toolchains, with and without GMP etc, we will use the one with those libraries.
  TOOLCHAIN_BIN_DIR=""

  local -r SHOULD_SKIP_TOOLCHAIN_WITH_GMP_MPFR_MPC="${DEBUGDUE_SKIP_TOOLCHAIN_WITH_GMP_MPFR_MPC:-false}"

  if ! $SHOULD_SKIP_TOOLCHAIN_WITH_GMP_MPFR_MPC; then

    local -r BUILD_DIR="$ROTATED_DIR/$L_LIBC_NAME/Toolchain-Build"
    local -r INSTALLATION_DIR="$ROTATED_DIR/$L_LIBC_NAME/Toolchain-Bin"

    printf -v L_CMD \
           "make  %s  %s  TARGET_LIBC=%q TARBALLS_DOWNLOAD_DIR=%q  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  all" \
           "$USUAL_MAKE_ARGS" \
           "$PARALLEL_ARGS" \
           "$L_LIBC_NAME" \
           "$DOWNLOADED_TARBALLS_DIRNAME" \
           "$INSTALLATION_DIR" \
           "$BUILD_DIR"

    run_cmd "Testing building the toolchain..." \
            "$L_CMD" \
            both  "$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-build-all.txt"


    # If environment variable LANG="C" were not set beforehand, we would need to do it here,
    # because we will be searching for an English text later on in the output.
    #   L_CMD="LANG=\"C\"  $L_CMD"

    run_cmd "Testing running the toolchain building makefile a second time..." \
            "$L_CMD" \
            both  "$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-build-all-2nd-time.txt"

    OUTPUT_FILE_CONTENTS=$(<"$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-build-all-2nd-time.txt")

    local -r NOTHING_TO_DO_REGEX=".*Nothing to be done for.*"

    if ! [[ $OUTPUT_FILE_CONTENTS =~ $NOTHING_TO_DO_REGEX ]]; then
      abort "Trying to run the makefile as second time still finds something to be built."
    fi

    if [ -z "$TOOLCHAIN_BIN_DIR" ]; then
      TOOLCHAIN_BIN_DIR="$INSTALLATION_DIR"
    fi


    if ! $SHOULD_SKIP_TOOLCHAIN_CHECK; then

      printf -v L_CMD \
             "make %s  %s  TARGET_LIBC=%q  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  check" \
             "$USUAL_MAKE_ARGS" \
             "$PARALLEL_ARGS" \
             "$L_LIBC_NAME" \
             "$INSTALLATION_DIR" \
             "$BUILD_DIR"

      run_cmd "Checking the toolchain..." \
              "$L_CMD" \
              both  "$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-check.txt"

    fi

  fi


  # If you want to build a toolchain without GMP, MPFR and MPC, you must have those libraries
  # installed on your host system.

  local -r SHOULD_SKIP_TOOLCHAIN_WITHOUT_GMP_MPFR_MPC="${DEBUGDUE_SKIP_TOOLCHAIN_WITHOUT_GMP_MPFR_MPC:-true}"

  if ! $SHOULD_SKIP_TOOLCHAIN_WITHOUT_GMP_MPFR_MPC; then

    local -r BUILD_DIR_WITHOUT_GMP_MPFR_MPC="$ROTATED_DIR/$L_LIBC_NAME/Toolchain-WithoutGmpMpfrMpc-Build"
    local -r INSTALLATION_DIR_WITHOUT_GMP_MPFR_MPC="$ROTATED_DIR/$L_LIBC_NAME/Toolchain-WithoutGmpMpfrMpc-Bin"

    printf -v L_CMD \
           "make %s  %s  TARGET_LIBC=%q TARBALLS_DOWNLOAD_DIR=%q CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  BUILD_GMP_MPFR_MPC=0  all" \
           "$USUAL_MAKE_ARGS" \
           "$PARALLEL_ARGS" \
           "$L_LIBC_NAME" \
           "$DOWNLOADED_TARBALLS_DIRNAME" \
           "$INSTALLATION_DIR_WITHOUT_GMP_MPFR_MPC" \
           "$BUILD_DIR_WITHOUT_GMP_MPFR_MPC"

    run_cmd "Building the toolchain without GMP, MPFR and MPC..." \
            "$L_CMD" \
            both  "$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-build-all-without-gmp-mpfr-mpc.txt"

    # Here we could to the same test too as for the other toolchain: "Testing running the toolchain building makefile a second time..."

    if [ -z "$TOOLCHAIN_BIN_DIR" ]; then
      TOOLCHAIN_BIN_DIR="$INSTALLATION_DIR_WITHOUT_GMP_MPFR_MPC"
    fi

    if ! $SHOULD_SKIP_TOOLCHAIN_CHECK; then

      printf -v L_CMD \
             "make %s  %s  TARGET_LIBC=%q  CROSS_TOOLCHAIN_DIR=%q  CROSS_TOOLCHAIN_BUILD_DIR=%q  BUILD_GMP_MPFR_MPC=0  check" \
             "$USUAL_MAKE_ARGS" \
             "$PARALLEL_ARGS" \
             "$L_LIBC_NAME" \
             "$INSTALLATION_DIR_WITHOUT_GMP_MPFR_MPC" \
             "$BUILD_DIR_WITHOUT_GMP_MPFR_MPC"

      run_cmd "Checking the toolchain without GMP, MPFR and MPC..." \
              "$L_CMD" \
              both  "$LOG_FILES_DIRNAME/toolchain-$L_LIBC_NAME-make-check-without-gmp-mpfr-mpc.txt"
    fi

  fi
}


test_basic_functions_of_firmware_build_script ()
{
  if false; then
    echo
    echo "Testing the basic functions of the firmware build script..."
  fi


  local L_CMD


  printf -v L_CMD \
         "%q --help" \
         "$COPY_OF_REPOSITORY/DebugDueBuilder.sh"

  run_cmd "Testing the DebugDue builder script with --help ..." \
          "$L_CMD" \
          stdout  "$LOG_FILES_DIRNAME/DebugDueBuilder-output-help.txt"


  if false; then

    # Unfortunately, we cannot unpack the ASF automatically, because you need to patch it manually before using it.

    PATH_TO_ASF_TARBALL="$HOME/path/to/xdk-asf-3.xx.x.zip"

    local -r ASF_UNPACK_BASEDIR="$ROTATED_DIR/AsfUnpacked"

    printf -v L_CMD  "unzip -q -d %q  %q"  "$ASF_UNPACK_BASEDIR"  "$PATH_TO_ASF_TARBALL"
    run_cmd  "Unpacking the ASF..."  "$CMD"  stdout  ""


    # Find the ASF root. The "_*" rule skips weird directory names like "__MACOSX".

    echo
    echo "Finding the ASF root dir..."

    printf -v L_CMD  "find  %q  -type d  -name '_*' -prune  -o -path '*/sam/drivers' -print"  "$ASF_UNPACK_BASEDIR"
    echo "$L_CMD"
    DIR_MATCH="$(eval "$L_CMD")"

    # echo "DIR_MATCH: $DIR_MATCH"

    DEBUGDUE_ASF_PATH="$(readlink --canonicalize --verbose -- "$DIR_MATCH/../..")"

  elif ! is_var_set "DEBUGDUE_ASF_PATH"; then

    abort "Environment variable DEBUGDUE_ASF_PATH is not set."

  fi
}


build_firmwares ()
{
  local -r L_LIBC_NAME="$1"
  local -r L_TOOLCHAIN_BIN_DIR="$2"

  echo
  echo "Building firmwares with $L_LIBC_NAME, toolchain \"$L_TOOLCHAIN_BIN_DIR\"..."

  local -r OUTPUT_BASE_DIR="$ROTATED_DIR/$L_LIBC_NAME/Firmwares"

  # In case we are reusing an output directory, delete any existing firmwares,
  # so that we rebuild all of them from scratch.
  rm -rf -- "$OUTPUT_BASE_DIR"

  pushd "$COPY_OF_REPOSITORY" >/dev/null

  # About option '--show-build-commands': Sometimes it is useful to look at the compiler flags used when building the projects.
  local BUILD_BASE_CMD
  printf -v BUILD_BASE_CMD \
         "%q  --show-build-commands  --toolchain-dir=%q  --build-output-base-dir=%q" \
         "./DebugDueBuilder.sh" \
         "$L_TOOLCHAIN_BIN_DIR" \
         "$OUTPUT_BASE_DIR"

  local BUILD_BASE_ASF_CMD
  printf -v BUILD_BASE_ASF_CMD \
         "%s  --atmel-software-framework=%q" \
         "$BUILD_BASE_CMD" \
         "$DEBUGDUE_ASF_PATH"

  run_cmd "Building DebugDue, debug build..." \
          "$BUILD_BASE_ASF_CMD  --build-type=debug --build" \
          both  "$LOG_FILES_DIRNAME/DebugDueBuilder-$L_LIBC_NAME-DebugDue-debug.txt"

  # We only test '--disassemble' with one firmware. That should be enough.
  run_cmd "Building DebugDue, debug build with disassemble..." \
          "$BUILD_BASE_ASF_CMD  --build-type=debug --build --disassemble" \
          both  "$LOG_FILES_DIRNAME/DebugDueBuilder-$L_LIBC_NAME-DebugDue-debug-disassemble.txt"

  run_cmd "Building DebugDue, release build..." \
          "$BUILD_BASE_ASF_CMD  --build-type=release --build" \
          both  "$LOG_FILES_DIRNAME/DebugDueBuilder-$L_LIBC_NAME-DebugDue-release.txt"

  run_cmd "Building EmptyFirmware, debug build..." \
          "$BUILD_BASE_ASF_CMD  --project=EmptyFirmware --build-type=debug --build" \
          both  "$LOG_FILES_DIRNAME/DebugDueBuilder-$L_LIBC_NAME-EmptyFirmware-debug.txt"

  run_cmd "Building EmptyFirmware, release build..." \
          "$BUILD_BASE_ASF_CMD  --project=EmptyFirmware --build-type=release --build" \
          both "$LOG_FILES_DIRNAME/DebugDueBuilder-$L_LIBC_NAME-EmptyFirmware-release.txt"

  run_cmd "Building QemuFirmware, debug build..." \
          "$BUILD_BASE_CMD  --project=QemuFirmware --build-type=debug --build" \
          both  "$LOG_FILES_DIRNAME/DebugDueBuilder-$L_LIBC_NAME-QemuFirmware-debug.txt"

  run_cmd "Building QemuFirmware, release build..." \
          "$BUILD_BASE_CMD  --project=QemuFirmware --build-type=release --build" \
          both  "$LOG_FILES_DIRNAME/DebugDueBuilder-$L_LIBC_NAME-QemuFirmware-release.txt"

  popd >/dev/null
}


quote_and_append_args ()
{
  local -n VAR="$1"
  shift

  local STR

  # Shell-quote all arguments before joining them into a single string.
  printf -v STR  "%q "  "$@"

  # Remove the last character, which is one space too much.
  STR="${STR::-1}"

  if [ -z "$VAR" ]; then
    VAR="$STR"
  else
    VAR+="  $STR"
  fi
}


collect_filenames ()
{
  local -r DIRNAME="$1"
  local -r CMD="$2"

  pushd "$DIRNAME" >/dev/null

  COLLECTED_FILENAMES=()

  local FILENAME
  while IFS='' read -r -d '' FILENAME; do

    if false; then
      echo "Filename: $FILENAME"
    fi

    COLLECTED_FILENAMES+=( "$FILENAME" )

  done < <( eval "$CMD" )

  popd >/dev/null

  local -i COLLECTED_FILENAMES_COUNT="${#COLLECTED_FILENAMES[@]}"

  if (( COLLECTED_FILENAMES_COUNT == 0 )); then
    abort "No files found in \"$DIRNAME\" with the given command."
  fi
}


lint_sources ()
{
  pushd "$COPY_OF_REPOSITORY" >/dev/null

  echo
  echo "Linting the files with a plain text linter..."

  local CMD=""

  quote_and_append_args CMD "find" "."

  # Skip some directories.

  quote_and_append_args CMD "-type" "d" "("

  quote_and_append_args CMD "-name" ".git"
  quote_and_append_args CMD "-o"
  quote_and_append_args CMD "-name" "BuildOutput"
  quote_and_append_args CMD "-o"
  quote_and_append_args CMD "-name" "SelfTestOutput"
  quote_and_append_args CMD "-o"
  quote_and_append_args CMD "-name" "Tarballs"
  quote_and_append_args CMD "-o"
  quote_and_append_args CMD "-name" "autom4te.cache"
  quote_and_append_args CMD "-o"
  quote_and_append_args CMD "-name" "build-aux"

  quote_and_append_args CMD ")" "-prune" "-false"


  quote_and_append_args CMD "-o" "-type" "f"

  # Skip some files, like Makefile and patches, because they have tabs, trailing spaces
  # or are otherwise not worth linting.

  quote_and_append_args CMD "-not" "-name" "Makefile*"
  quote_and_append_args CMD "-not" "-name" "*.mk"
  quote_and_append_args CMD "-not" "-name" "*.m4"
  quote_and_append_args CMD "-not" "-name" "*.patch"
  quote_and_append_args CMD "-not" "-name" "configure"

  quote_and_append_args CMD "-printf" '%P\0'

  collect_filenames "." "$CMD"

  if false; then
    echo "${#COLLECTED_FILENAMES[@]} array elements:"
    printf -- '- %s\n' "${COLLECTED_FILENAMES[@]}"
  fi

  # We do not need xarg's '--no-run-if-empty', because the array will never be empty.

  printf -- '%s\0' "${COLLECTED_FILENAMES[@]}" | xargs --null ptlint.pl --no-trailing-whitespace --no-tabs --eol=only-lf --only-ascii --no-control-codes --

  echo "${#COLLECTED_FILENAMES[@]} files linted."

  popd >/dev/null
}


# ----- Entry point -----

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments."
fi


declare -r ROTATED_DIR="$1"

declare -r COPY_OF_REPOSITORY="$ROTATED_DIR/CopyOfRepository"
declare -r LOG_FILES_DIRNAME="$ROTATED_DIR/BuildLogs"

echo "Creating \"$LOG_FILES_DIRNAME\" ..."
mkdir --parents -- "$LOG_FILES_DIRNAME"


declare -r SHOULD_LINT="${DEBUGDUE_SHOULD_LINT:-true}"
declare -r SHOULD_BUILD_TOOLCHAINS="${DEBUGDUE_SHOULD_BUILD_TOOLCHAINS:-true}"
declare -r SHOULD_BUILD_FIRMWARES="${DEBUGDUE_SHOULD_BUILD_FIRMWARES:-true}"


# Environment variable DEBUGDUE_LIBC_VARIANTS should contain a space-separated list of libcs.
declare -r LIBC_VARIANTS="${DEBUGDUE_LIBC_VARIANTS:-newlib picolibc}"

read -r -a LIBC_VARIANTS_ARRAY <<< "$LIBC_VARIANTS"

declare -r -i LIBC_VARIANTS_ARRAY_COUNT="${#LIBC_VARIANTS_ARRAY[@]}"

if $SHOULD_LINT; then
  lint_sources
fi

declare -a TOOLCHAIN_BIN_DIR_ARRAY=()

if $SHOULD_BUILD_TOOLCHAINS; then

  pushd "$COPY_OF_REPOSITORY/Toolchain" >/dev/null

  declare -r USUAL_MAKE_ARGS="--no-builtin-variables  --warn-undefined-variables"

  get_make_parallel_args

  test_basic_functions_of_toolchain_makefile

  for LIBC_NAME in "${LIBC_VARIANTS_ARRAY[@]}"; do

    test_building_toolchain "$LIBC_NAME"

    # Sometimes building of the actual toolchains is skipped.
    if [ -n "$TOOLCHAIN_BIN_DIR" ]; then
      TOOLCHAIN_BIN_DIR_ARRAY+=( "$TOOLCHAIN_BIN_DIR" )
    fi

  done

  popd >/dev/null

fi


if $SHOULD_BUILD_FIRMWARES; then

  if (( ${#TOOLCHAIN_BIN_DIR_ARRAY[@]} == 0 )); then

    # Environment variable DEBUGDUE_TOOLCHAIN_PATHS should contain a space-separated list of
    # paths to the toolchain bin directories.
    declare -r TOOLCHAIN_PATHS="${DEBUGDUE_TOOLCHAIN_PATHS:-}"

    read -r -a TOOLCHAIN_PATHS_ARRAY <<< "$TOOLCHAIN_PATHS"

    if false; then
      echo "Libcs: ${LIBC_VARIANTS_ARRAY[*]}"
      echo "Toolchains: ${TOOLCHAIN_PATHS_ARRAY[*]}"
    fi

    declare -r -i TOOLCHAIN_PATHS_ARRAY_COUNT="${#TOOLCHAIN_PATHS_ARRAY[@]}"

    if (( TOOLCHAIN_PATHS_ARRAY_COUNT != LIBC_VARIANTS_ARRAY_COUNT )); then
      abort "$TOOLCHAIN_PATHS_ARRAY_COUNT toolchain path(s) were supplied, but $LIBC_VARIANTS_ARRAY_COUNT libc variant(s) were given."
    fi

    TOOLCHAIN_BIN_DIR_ARRAY=( "${TOOLCHAIN_PATHS_ARRAY[@]}" )

  fi

  test_basic_functions_of_firmware_build_script

  for (( I=0; I < LIBC_VARIANTS_ARRAY_COUNT; I++ )); do

    build_firmwares  "${LIBC_VARIANTS_ARRAY[$I]}"  "${TOOLCHAIN_BIN_DIR_ARRAY[$I]}"

  done

fi

echo
echo "All self-tests finished."

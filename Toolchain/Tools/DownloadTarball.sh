#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.12"

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


create_dir_if_not_exists ()
{
  # $1 = dir name

  if ! test -d "$1"
  then
    # echo "Creating directory \"$1\" ..."
    mkdir --parents -- "$1"
  fi
}


is_dir_empty ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command (or operation) invoked.
  local -a FILES
  FILES=( "$1"/* )

  if [ ${#FILES[@]} -eq 0 ]; then
    return $BOOLEAN_TRUE
  else
    if false; then
      echo "Files found: ${FILES[*]}"
    fi
    return $BOOLEAN_FALSE
  fi
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014-2025 R. Diez - Licensed under the GNU AGPLv3

This script reliably downloads a tarball or zip/jar file by testing its integrity
before committing the downloaded file to the destination directory.
It can also unpack the tarball to a given directory.

If the tarball is already there, the download and test operations are skipped.

Tool 'curl' is called to perform the actual download.
The destination directory must exist beforehand.

Some file mirrors use HTML redirects that 'curl' cannot follow properly, so it may
end up downloading an HTML error page instead of a valid tarball file.
In order to minimize room for such download errors, this script creates a
temporary subdirectory in the destination directory, named like
tarball.tgz${DOWNLOAD_IN_PROGRESS_SUBDIRNAME_SUFFIX}, and downloads the file there.
Afterwards, the tarball's integrity is tested and optionally decompressed there.
The tarball file is only committed (moved) to the destination directory if the test succeeds.

This way, it is very hard to download a corrupt file and not immediately notice.
Even if you interrupt the transfer, the destination directory will never
end up containing corrupt tarballs.

Should an error occur, the corrupted file is left for the user to manually inspect.
The corresponding error message shows then the corrupted file's location.

Option '--$UNPACK_TO_NEW_DIR_OPT_NAME' unpacks the tarball to the given directory.
Again, this tool will only move the unpacked files there if the whole
unpack operation succeeds, so it is hard to end up with an incomplete set of unpacked files.
The given directory is meant to be for this tarball only,
and will be deleted and recreated before unpacking if it already existed.

If the tarball was already downloaded, but the directory to unpack to does not exist,
then the existing tarball is unpacked. The idea is that, if you modify the unpack directory
and then delete it, it will be recreated automatically from the previously-downloaded tarball.

Syntax:
  $SCRIPT_NAME  [options...]  <url>  <destination dir>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information
 --$UNPACK_TO_NEW_DIR_OPT_NAME="dest-dir"
            Unpacks the tarball into the given directory.
            If the tarball already exists, but the destination directory does not,
            then only unpacking is performed.
            The given directory will be deleted and recreated when unpacking.
            This option is incompatible with --test-with-full-extraction .
 --remove-first-level
            Many tarballs contain a single directory with a similar name as the tarball.
            For example, "gdb-7.9.tar.xz" has a single directory inside called "gdb-7.9".
            This options removes that single directory level when unpacking to the destination directory.
            Only valid if specified together with --$UNPACK_TO_NEW_DIR_OPT_NAME.
 --test-with-full-extraction
            The integrity test extracts all files to a temporary directory,
            which is then deleted if successful. Otherwise, "tar --to-stdout >/dev/null"
            is used, which should be reliable enough for integrity test purposes.
            This option makes no difference for .zip files.
            This option is incompatible with --$UNPACK_TO_NEW_DIR_OPT_NAME .

Usage examples:
  \$ mkdir "downloaded-files"
  \$ ./$SCRIPT_NAME "http://ftpmirror.gnu.org/gdb/gdb-7.8.tar.xz" "downloaded-files"
  \$ ./$SCRIPT_NAME --$UNPACK_TO_NEW_DIR_OPT_NAME="gdb-src" -- "http://ftpmirror.gnu.org/gdb/gdb-7.9.tar.xz" "downloaded-files"

Possible performance improvements still to implement:
 - Implement a shallower integrity check that just scans the filenames in the tarball
   with tar's --list option. Such a simple check should suffice in most scenarios
   and is probably faster than unpacking the file contents.
 - Alternatively, if the .tar file is compressed (for example, as a .tar.gz),
   checking the compressed checksum of the whole .tar file without unpacking
   all the files inside could also be a good compromise.

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiez-tools at rd10.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2014-2025 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

EOF
}


process_command_line_argument ()
{
  # Disable this ShellCheck warning because of $UNPACK_TO_NEW_DIR_OPT_NAME below.
  # shellcheck disable=SC2254
  case "$OPTION_NAME" in
    help)
        display_help
        exit $EXIT_CODE_SUCCESS
        ;;
    version)
        echo "$VERSION_NUMBER"
        exit $EXIT_CODE_SUCCESS
        ;;
    license)
        display_license
        exit $EXIT_CODE_SUCCESS
        ;;
    $UNPACK_TO_NEW_DIR_OPT_NAME)
        if [[ $OPTARG = "" ]]; then
          abort "Option --$UNPACK_TO_NEW_DIR_OPT_NAME has an empty value.";
        fi
        UNPACK_TO_DIR="$OPTARG"
        ;;
    remove-first-level)
        REMOVE_FIRST_LEVEL=true
        ;;
    test-with-full-extraction)
        TEST_WITH_FULL_EXTRACTION=true
        ;;
    *)  # We should actually never land here, because parse_command_line_arguments() already checks if an option is known.
        abort "Unknown command-line option \"--${OPTION_NAME}\".";;
  esac
}


parse_command_line_arguments ()
{
  # The way command-line arguments are parsed below was originally described on the following page:
  #   http://mywiki.wooledge.org/ComplexOptionParsing
  # But over the years I have rewritten or amended most of the code myself.

  if false; then
    echo "USER_SHORT_OPTIONS_SPEC: $USER_SHORT_OPTIONS_SPEC"
    echo "Contents of USER_LONG_OPTIONS_SPEC:"
    for key in "${!USER_LONG_OPTIONS_SPEC[@]}"; do
      printf -- "- %s=%s\\n" "$key" "${USER_LONG_OPTIONS_SPEC[$key]}"
    done
  fi

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  local MY_OPT_SPEC=":-:$USER_SHORT_OPTIONS_SPEC"

  local OPTION_NAME
  local OPT_ARG_COUNT
  local OPTARG  # This is a standard variable in Bash. Make it local just in case.
  local OPTARG_AS_ARRAY

  while getopts "$MY_OPT_SPEC" OPTION_NAME; do

    case "$OPTION_NAME" in

      -) # This case triggers for options beginning with a double hyphen ('--').
         # If the user specified "--longOpt"   , OPTARG is then "longOpt".
         # If the user specified "--longOpt=xx", OPTARG is then "longOpt=xx".

         if [[ "$OPTARG" =~ .*=.* ]]  # With this --key=value format, only one argument is possible.
         then

           OPTION_NAME=${OPTARG/=*/}
           OPTARG=${OPTARG#*=}
           OPTARG_AS_ARRAY=("")

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT != 1 )); then
             abort "Command-line option \"--$OPTION_NAME\" does not take 1 argument."
           fi

           process_command_line_argument

         else  # With this format, multiple arguments are possible, like in "--key value1 value2".

           OPTION_NAME="$OPTARG"

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT == 0 )); then
             OPTARG=""
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           elif (( OPT_ARG_COUNT == 1 )); then
             # If this is the last option, and its argument is missing, then OPTIND is out of bounds.
             if (( OPTIND > $# )); then
               abort "Option '--$OPTION_NAME' expects one argument, but it is missing."
             fi
             OPTARG="${!OPTIND}"
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           else
             OPTARG=""
             # OPTARG_AS_ARRAY is not standard in Bash. I have introduced it to make it clear that
             # arguments are passed as an array in this case. It also prevents many Shellcheck warnings.
             OPTARG_AS_ARRAY=("${@:OPTIND:OPT_ARG_COUNT}")

             if [ ${#OPTARG_AS_ARRAY[@]} -ne "$OPT_ARG_COUNT" ]; then
               abort "Command-line option \"--$OPTION_NAME\" needs $OPT_ARG_COUNT arguments."
             fi

             process_command_line_argument
           fi

           ((OPTIND+=OPT_ARG_COUNT))
         fi
         ;;

      *) # This processes only single-letter options.
         # getopts knows all valid single-letter command-line options, see USER_SHORT_OPTIONS_SPEC above.
         # If it encounters an unknown one, it returns an option name of '?'.
         if [[ "$OPTION_NAME" = "?" ]]; then
           abort "Unknown command-line option \"$OPTARG\"."
         else
           # Process a valid single-letter option.
           OPTARG_AS_ARRAY=("")
           process_command_line_argument
         fi
         ;;
    esac
  done

  shift $((OPTIND-1))
  ARGS=("$@")
}


# This routine sets variable TAR_EXIT_CODE, which then the caller should check.

unpack_tarball ()
{
  # If the directory already exists, delete it.
  rm -rf -- "$TMP_UNPACK_DIR_ABS"
  mkdir -- "$TMP_UNPACK_DIR_ABS"

  pushd "$TMP_UNPACK_DIR_ABS" >/dev/null

  # Script unpack.sh in the same repository as this script handles many more file formats.

  case "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS" in

    *.zip|*.jar)
      set +o errexit
      unzip -q "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS"
      TAR_EXIT_CODE="$?"
      set -o errexit
      ;;

    *)
      set +o errexit
      tar --extract --auto-compress --file "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS"
      TAR_EXIT_CODE="$?"
      set -o errexit
      ;;
  esac

  popd >/dev/null
}


# ------ Entry Point (only by convention) ------

# About option 'unpack-to-new-dir':
#
# This script used to have an option called '--unpack-to', which would unpack the tarball to the given directory,
# overwriting anything with the same filenames, but leaving other existing files there unmodified.
#
# The behaviour has changed, we the option name had to change. Otherwise, the new behaviour
# would delete files and wreak havoc in old scripts using '--unpack-to'.
#
# The problem with the old '--unpack-to' approach is that unpacking is not an atomic operation.
# The next time around, the script would not know whether the previous unpacking finished successfully,
# so it would have to unpack and overwrite all files again, just in case.
#
# In order to prevent that, the script could generate a sentinel file at the end of a successful unpacking.
# But then it would be difficult to delete all unpacked files and unpack the tarball again,
# as orphaned files could be left behind.
#
# The new 'unpack-to-new-dir' implements a different approach: the tarball is unpacked
# to a temporary directory, which is renamed to the given directory name only after unpacking
# finished successfully. That is, the presence of the final unpacked directory name
# is used as an indication that the unpacking was successful in a previous invocation.
#
# The idea is that, if the user unpacks a tarball and then modifies the unpacked files,
# say by applying patches, it should be easy to reset the changes without re-downloading the tarball:
# Just delete the unpacked directory, and this script will unpack the previously-downloaded tarball again.
#
# The current approach has one limitation though: a tarball can only be unpacked to
# a single destination directory. If you wish to combine 2 tarballs in the same destination directory,
# then you have to implement it outside this script, possibly with sentinel files,
# in the same way as you would implement patch management over the unpacked files.
declare -r UNPACK_TO_NEW_DIR_OPT_NAME="unpack-to-new-dir"

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [remove-first-level]=0 )
USER_LONG_OPTIONS_SPEC+=( [test-with-full-extraction]=0 )
USER_LONG_OPTIONS_SPEC+=( [$UNPACK_TO_NEW_DIR_OPT_NAME]=1 )

TEST_WITH_FULL_EXTRACTION=false
REMOVE_FIRST_LEVEL=false
UNPACK_TO_DIR=""

declare -r DOWNLOAD_IN_PROGRESS_SUBDIRNAME_SUFFIX="-download-in-progress"

parse_command_line_arguments "$@"

if [ ${#ARGS[@]} -ne 2 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

declare -r URL="${ARGS[0]}"
declare -r DESTINATION_DIR="${ARGS[1]}"

if ! [ -d "$DESTINATION_DIR" ]; then
  abort "Destination directory \"$DESTINATION_DIR\" does not exist."
fi

declare -r NAME_ONLY="${URL##*/}"

DESTINATION_DIR_ABS="$(readlink --verbose --canonicalize -- "$DESTINATION_DIR")"
readonly DESTINATION_DIR_ABS

declare -r FINAL_TARBALL_FILENAME_ABS="$DESTINATION_DIR_ABS/$NAME_ONLY"

if [[ $UNPACK_TO_DIR != "" ]]; then

  if $TEST_WITH_FULL_EXTRACTION; then
    abort "Options '--$UNPACK_TO_NEW_DIR_OPT_NAME' and '--test-with-full-extraction' are incompatible."
  fi

  UNPACK_TO_DIR_ABS="$(readlink --verbose --canonicalize -- "$UNPACK_TO_DIR")"
  readonly UNPACK_TO_DIR_ABS

else

  declare -r UNPACK_TO_DIR_ABS=""

  if $REMOVE_FIRST_LEVEL; then
    abort "Option '--remove-first-level' can only be specified with '--$UNPACK_TO_NEW_DIR_OPT_NAME'."
  fi

fi

# The main reason why we create a temporary subdirectory is to keep the original tarball name,
# because the unpack tools may use its file extension as a hint about how to unpack it.
# Without a separate subdirectory, we would need to create a similar temporary filename
# with the relevant file extension, for example tarball.tar.gz -> tarball-tmp.tar.gz .
# The temporary directory should be in the same filesystem, because otherwise
# the move operation at the end is not atomic.
declare -r DOWNLOAD_IN_PROGRESS_DIR_ABS="$DESTINATION_DIR_ABS/${NAME_ONLY}${DOWNLOAD_IN_PROGRESS_SUBDIRNAME_SUFFIX}"

declare -r TMP_UNPACK_DIR_ABS="$DOWNLOAD_IN_PROGRESS_DIR_ABS/$NAME_ONLY-unpacked"

if [ -f "$FINAL_TARBALL_FILENAME_ABS" ]; then

  echo "Skipped dowloading file \"$URL\", as it already exists at: $FINAL_TARBALL_FILENAME_ABS"

  if [[ $UNPACK_TO_DIR_ABS = "" ]]; then

    # We could try to delete directory $DOWNLOAD_IN_PROGRESS_DIR_ABS here if it exists,
    # but we haven't created it ourselves, at least in this invocation.

    exit $EXIT_CODE_SUCCESS

  fi

  if [ -d "$UNPACK_TO_DIR_ABS" ]; then

    echo "Skipped unpacking the tarball, as the unpacked files already exist at: $UNPACK_TO_DIR_ABS"

    exit $EXIT_CODE_SUCCESS

  fi

  # Note that, if the tarball is downloaded, then the unpacked directory will always be recreated.

  declare -r TARBALL_ALREADY_EXISTS=true

  declare -r DOWNLOADED_TARBALL_TEMP_FILENAME_ABS="$FINAL_TARBALL_FILENAME_ABS"

else

  declare -r TARBALL_ALREADY_EXISTS=false

  declare -r DOWNLOADED_TARBALL_TEMP_FILENAME_ABS="$DOWNLOAD_IN_PROGRESS_DIR_ABS/$NAME_ONLY"

fi


if ! $TARBALL_ALREADY_EXISTS; then

  echo "Downloading URL \"$URL\"..."

  create_dir_if_not_exists "$DOWNLOAD_IN_PROGRESS_DIR_ABS"

  # Optional flags: --silent (then with --show-error), --ftp-pasv, --ftp-method nocwd
  #
  # About option '--stderr -': Some users consider anything written to stderr to be a warning
  # or an error that needs the user's attention. Curl writes its progress indication to stderr,
  # but that is not warning or error to worry about, so redirect the progress indication to stdout.
  #
  # Option --location makes curl follow redirects.
  #
  # Option --fail makes curl return an non-zero exit code if the server reports an error, like file not found.

  curl --location --fail --stderr - --url "$URL" --output "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS"

fi


if [[ $UNPACK_TO_DIR_ABS != "" ]]; then

  echo "Unpacking tarball \"$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS\"..."

  create_dir_if_not_exists "$DOWNLOAD_IN_PROGRESS_DIR_ABS"

  unpack_tarball

  if [ $TAR_EXIT_CODE -ne 0 ]; then
    ERR_MSG="The downloaded tarball \"$URL\" failed to unpack, see above for the detailed error message."
    ERR_MSG="${ERR_MSG} The file may be corrupt, or curl may not have been able to follow a redirect properly."
    ERR_MSG="${ERR_MSG} Try downloading the tarball file from another location or mirror."
    ERR_MSG="${ERR_MSG} You can inspect the corrupt file at \"$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS\"."
    abort "$ERR_MSG"
  fi

  # If unpacking was successful, move the tarball first (assuming we have just downloaded it).
  # If moving the unpacked directory fails later on, at least we will not re-download the tarball.

  if ! $TARBALL_ALREADY_EXISTS; then

    # Before moving the downloaded tarball, delete any old unpacked directory.
    # Otherwise, its old contents may not match the newly-downloaded tarball.
    # We could do it before unpacking above, in order to conserve disk space.

    if [ -d "$UNPACK_TO_DIR_ABS" ]; then
      echo "Deleting old unpacked directory \"$UNPACK_TO_DIR_ABS\"..."
      rm -rf -- "$UNPACK_TO_DIR_ABS"
    fi

    echo "Moving the downloaded tarball to \"$FINAL_TARBALL_FILENAME_ABS\"..."

    mv -- "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS" "$FINAL_TARBALL_FILENAME_ABS"

  fi

  echo "Moving the unpacked directory to \"$UNPACK_TO_DIR_ABS\"..."

  # We need to remove the eventually existing directory first, or the move may fail.
  rm -rf -- "$UNPACK_TO_DIR_ABS"

  if $REMOVE_FIRST_LEVEL; then

    shopt -s nullglob
    shopt -s dotglob  # Include hidden files.

    declare -a FILES_IN_TMP_DIR=( "$TMP_UNPACK_DIR_ABS"/* )

    declare -r -i UNPACKED_FILE_COUNT="${#FILES_IN_TMP_DIR[@]}"

    if (( UNPACKED_FILE_COUNT != 1 )); then
      abort "Option '--remove-first-level' was specified, but the tarball has more than one file or directory at top level."
    fi

    declare -r THE_ONLY_FILENAME_ABS="${FILES_IN_TMP_DIR[0]}"

    if ! [ -d "$THE_ONLY_FILENAME_ABS" ]; then
      abort "Option '--remove-first-level' was specified, but the tarball does not have a top-level directory."
    fi

    mv -- "$THE_ONLY_FILENAME_ABS" "$UNPACK_TO_DIR_ABS"

    # The temporary directory must be empty, or removing it later on will fail.
    rmdir -- "$TMP_UNPACK_DIR_ABS"

  else
    mv -- "$TMP_UNPACK_DIR_ABS" "$UNPACK_TO_DIR_ABS"
  fi

else  # Only test the downloaded tarball.


  case "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS" in

    *.zip|*.jar)
      echo "Testing the downloaded archive file \"$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS\"..."
      set +o errexit
      unzip -qt "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS"
      TAR_EXIT_CODE="$?"
      set -o errexit
      ;;

    *)
      if $TEST_WITH_FULL_EXTRACTION; then

        echo "Testing with full extraction the downloaded tarball \"$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS\"..."

        unpack_tarball

        rm -rf -- "$TMP_UNPACK_DIR_ABS"

      else

        echo "Testing the downloaded tarball \"$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS\"..."

        set +o errexit
        tar --extract --auto-compress --to-stdout --file "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS" >/dev/null
        TAR_EXIT_CODE="$?"
        set -o errexit

      fi
  esac

  if [ $TAR_EXIT_CODE -ne 0 ]; then
    ERR_MSG="The downloaded tarball \"$URL\" failed the integrity test, see above for the detailed error message."
    ERR_MSG="${ERR_MSG} The file may be corrupt, or curl may not have been able to follow a redirect properly."
    ERR_MSG="${ERR_MSG} Try downloading the tarball from another location or mirror."
    ERR_MSG="${ERR_MSG} You can inspect the corrupt file at \"$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS\"."
    abort "$ERR_MSG"
  fi

  echo "Moving the downloaded tarball to \"$FINAL_TARBALL_FILENAME_ABS\"..."

  # No need to check TARBALL_ALREADY_EXISTS here, as the tarball has always been freshly downloaded at this point.

  mv -- "$DOWNLOADED_TARBALL_TEMP_FILENAME_ABS" "$FINAL_TARBALL_FILENAME_ABS"

fi


if is_dir_empty "$DOWNLOAD_IN_PROGRESS_DIR_ABS"; then
  rmdir -- "$DOWNLOAD_IN_PROGRESS_DIR_ABS"
else
  abort "Cannot delete the temporary directory because it is not empty: $DOWNLOAD_IN_PROGRESS_DIR_ABS"
fi


echo "Finished processing tarball \"$NAME_ONLY\"."

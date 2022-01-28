#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r SCRIPT_NAME="DownloadTarball.sh"
declare -r VERSION_NUMBER="1.08"

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r DOWNLOAD_IN_PROGRESS_SUBDIRNAME="download-in-progress"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
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
Copyright (c) 2014-2019 R. Diez - Licensed under the GNU AGPLv3

This script reliably downloads a tarball by testing its integrity before
committing the downloaded file to the destination directory.

If the file is already there, the download and test operations are skipped.

The destination directory must exist beforehand. Tool 'curl' is called to
perform the actual download.

Some file mirrors use HTML redirects that 'curl' cannot follow properly, so it may
end up downloading an HTML error page instead of a valid tarball file.
In order to minimize room for such download errors, this script creates a
'$DOWNLOAD_IN_PROGRESS_SUBDIRNAME' subdirectory in the destination directory
and downloads the file there. Afterwards, the tarball's integrity is tested.
The tarball file is only committed (moved) to the destination directory if the test succeeds.

This way, it is very hard to download a corrupt file and not immediately notice.
Even if you interrupt the transfer, the destination directory will never end up containing
corrupt tarballs (except possibly in the '$DOWNLOAD_IN_PROGRESS_SUBDIRNAME' subdirectory).

Should an error occur, the corrupted file is left for the user to manually inspect.
The corresponding error message shows then the corrupted file's location.

Syntax:
  $SCRIPT_NAME  [options...]  <url>  <destination dir>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information
 --unpack-to="dest-dir"  Leaves the unpacked contents in the given directory.
                         This option is incompatible with --test-with-full-extraction .
                         Make sure tool "move-with-rsync.sh" is in your PATH.
 --test-with-full-extraction  The integrity test extracts all files to a temporary directory
                              created with 'mktemp'. Otherwise, "tar --to-stdout" is used,
                              which should be just as reliable for test purposes.
                              This option makes no difference for .zip files.
 --delete-download-dir  Delete the '$DOWNLOAD_IN_PROGRESS_SUBDIRNAME' subdirectory if
                        successful and empty. Do not use this option if running
                        several instances of this script in parallel.

Usage example:
  % mkdir somedir
  % ./$SCRIPT_NAME "http://ftpmirror.gnu.org/gdb/gdb-7.8.tar.xz" "somedir"

Possible performance improvements still to implement:
 - Implement a shallower integrity check that just scans the filenames in the tarball
   with tar's --list option. Such a simple check should suffice in most scenarios
   and is probably faster than extracting the file contents.
 - Alternatively, if the .tar file is compressed (for example, as a .tar.gz),
   checking the compressed checksum of the whole .tar file without extracting
   all the files inside could also be a good compromise.

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2014-2017 R. Diez

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
    unpack-to)
        if [[ $OPTARG = "" ]]; then
          abort "Option --unpack-to has an empty value.";
        fi
        UNPACK_TO_DIR="$OPTARG"
        ;;
    test-with-full-extraction)
        TEST_WITH_FULL_EXTRACTION=true
        ;;
    delete-download-dir)
       DELETE_DOWNLOAD_DIR=true
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
           fi;

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


# ----- Entry point -----

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [test-with-full-extraction]=0 )
USER_LONG_OPTIONS_SPEC+=( [delete-download-dir]=0 )
USER_LONG_OPTIONS_SPEC+=( [unpack-to]=1 )

TEST_WITH_FULL_EXTRACTION=false
DELETE_DOWNLOAD_DIR=false
UNPACK_TO_DIR=""

parse_command_line_arguments "$@"

if [ ${#ARGS[@]} -ne 2 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi


URL="${ARGS[0]}"
DESTINATION_DIR="${ARGS[1]}"

if ! [ -d "$DESTINATION_DIR" ]; then
  abort "Destination directory \"$DESTINATION_DIR\" does not exist."
fi

DESTINATION_DIR_ABS="$(readlink --verbose --canonicalize -- "$DESTINATION_DIR")"

NAME_ONLY="${URL##*/}"

FINAL_FILENAME="$DESTINATION_DIR_ABS/$NAME_ONLY"

if [ -f "$FINAL_FILENAME" ]; then
  echo "Skipping file \"$URL\", as it already exists in the destination directory."

  # If option --delete-download-dir was given, we could try to delete the directory here.

  exit $EXIT_CODE_SUCCESS
fi

DOWNLOAD_IN_PROGRESS_PATH="$DESTINATION_DIR_ABS/$DOWNLOAD_IN_PROGRESS_SUBDIRNAME"

create_dir_if_not_exists "$DOWNLOAD_IN_PROGRESS_PATH"

TEMP_FILENAME="$DOWNLOAD_IN_PROGRESS_PATH/$NAME_ONLY"

echo "Downloading URL \"$URL\"..."

# Optional flags: --silent, --ftp-pasv, --ftp-method nocwd
curl --location --show-error --url "$URL" --output "$TEMP_FILENAME"

if [[ ${UNPACK_TO_DIR:-} != "" ]]; then

    create_dir_if_not_exists "$UNPACK_TO_DIR"

    TMP_DIRNAME="$(mktemp --directory --tmpdir "$SCRIPT_NAME.XXXXXXXXXX")"

    pushd "$TMP_DIRNAME" >/dev/null

    case "$TEMP_FILENAME" in
      *.zip)
        echo "Extracting the downloaded zip file \"$TEMP_FILENAME\"..."
        set +o errexit
        unzip -q "$TEMP_FILENAME"
        TAR_EXIT_CODE="$?"
        set -o errexit
        ;;

      *)
        set +o errexit
        tar --extract --auto-compress --file "$TEMP_FILENAME"
        TAR_EXIT_CODE="$?"
        set -o errexit
        ;;
    esac

    popd >/dev/null

    if [ $TAR_EXIT_CODE -ne 0 ]; then
      rm -rf "$TMP_DIRNAME"
      ERR_MSG="Error unpacking the downloaded file."
      ERR_MSG="${ERR_MSG}The file may be corrupt, or curl may not have been able to follow a redirect properly. "
      ERR_MSG="${ERR_MSG}Try downloading the archive file from another location or mirror. "
      ERR_MSG="${ERR_MSG}You can inspect the corrupt file at \"$TEMP_FILENAME\"."
      abort "$ERR_MSG"
    fi

    set +o errexit
    move-with-rsync.sh "$TMP_DIRNAME/" "$UNPACK_TO_DIR"
    EXIT_CODE="$?"
    set -o errexit

    if [ $EXIT_CODE -ne 0 ]; then
      rm -rf "$TMP_DIRNAME"
      ERR_MSG="Error moving the files from \"$TMP_DIRNAME/\" \"$UNPACK_TO_DIR\"."
      abort "$ERR_MSG"
    fi

    rmdir "$TMP_DIRNAME"

else  # Only test the tarball.

  case "$TEMP_FILENAME" in
    *.zip|*.jar)
      echo "Testing the downloaded zip file \"$TEMP_FILENAME\"..."
      set +o errexit
      unzip -qt "$TEMP_FILENAME"
      TAR_EXIT_CODE="$?"
      set -o errexit
      ;;

    *)
      if $TEST_WITH_FULL_EXTRACTION; then
        echo "Testing with full extraction the downloaded tarball \"$TEMP_FILENAME\"..."

        TMP_DIRNAME="$(mktemp --directory --tmpdir "$SCRIPT_NAME.XXXXXXXXXX")"

        pushd "$TMP_DIRNAME" >/dev/null

        set +o errexit
        tar --extract --auto-compress --file "$TEMP_FILENAME"
        TAR_EXIT_CODE="$?"
        set -o errexit

        popd >/dev/null

        rm -rf -- "$TMP_DIRNAME"
      else
        echo "Testing the downloaded tarball \"$TEMP_FILENAME\"..."

        set +o errexit
        tar --extract --auto-compress --to-stdout --file "$TEMP_FILENAME" >/dev/null
        TAR_EXIT_CODE="$?"
        set -o errexit
      fi
  esac

fi

if [ $TAR_EXIT_CODE -ne 0 ]; then
  ERR_MSG="Downloaded archive file \"$URL\" failed the integrity test, see above for the detailed error message. "
  ERR_MSG="${ERR_MSG}The file may be corrupt, or curl may not have been able to follow a redirect properly. "
  ERR_MSG="${ERR_MSG}Try downloading the archive file from another location or mirror. "
  ERR_MSG="${ERR_MSG}You can inspect the corrupt file at \"$TEMP_FILENAME\"."
  abort "$ERR_MSG"
fi

mv "$TEMP_FILENAME" "$FINAL_FILENAME"

if $DELETE_DOWNLOAD_DIR; then
  if is_dir_empty "$DOWNLOAD_IN_PROGRESS_PATH"; then
    rmdir -- "$DOWNLOAD_IN_PROGRESS_PATH"
  else
    echo "Not deleting the download directory because it is not empty: $DOWNLOAD_IN_PROGRESS_PATH"
  fi
fi

# echo "Finished downloading file \"$URL\" to \"$FINAL_FILENAME\"."

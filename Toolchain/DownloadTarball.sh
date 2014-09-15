#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


SCRIPT_NAME="DownloadTarball.sh"
VERSION_NUMBER="1.0"

DOWNLOAD_IN_PROGRESS_SUBDIRNAME="download-in-progress"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
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


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

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
 --full-extraction  The integrity test extracts all files to a temporary directory
                    created with 'mktemp'. Otherwise, "tar --to-stdout" is used,
                    which should be just as reliable for test purposes.

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

Copyright (c) 2011 R. Diez

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




# ----- Entry point -----


# --------------------------------------------------


# The way command-arguments are parsed below is described on this page:  http://mywiki.wooledge.org/ComplexOptionParsing

# Use an associative array to declare how many arguments a long option expects.
# Long options that aren't listed in this way will have zero arguments by default.
declare -A MY_LONG_OPT_SPEC=()

# The first colon (':') means "use silent error reporting".
# The "-:" means an option can start with '-', which helps parse long options which start with "--".
MY_OPT_SPEC=":-:"

FULL_EXTRACTION=false

while getopts "$MY_OPT_SPEC" opt; do
  while true; do
    case "${opt}" in
        -)  # OPTARG is name-of-long-option or name-of-long-option=value
            if [[ "${OPTARG}" =~ .*=.* ]]  # With this --key=value format, only one argument is possible. See also below.
            then
                opt=${OPTARG/=*/}
                OPTARG=${OPTARG#*=}
                ((OPTIND--))
            else  # With this --key value1 value2 format, multiple arguments are possible.
                opt="$OPTARG"
                OPTARG=(${@:OPTIND:$((MY_LONG_OPT_SPEC[$opt]))})
            fi
            ((OPTIND+=MY_LONG_OPT_SPEC[$opt]))
            continue  # Now that opt/OPTARG are set, we can process them as if getopts would have given us long options.
            ;;
        help)
            display_help
            exit 0
            ;;
        version)
            echo "$VERSION_NUMBER"
            exit 0
            ;;
        license)
            display_license
            exit 0
            ;;
        full-extraction)
            FULL_EXTRACTION=true
            ;;
        *)
            if [[ ${opt} = "?" ]]; then
              abort "Unknown command-line option \"$OPTARG\"."
            else
              abort "Unknown command-line option \"${opt}\"."
            fi
            ;;
    esac
  break; done
done


shift $((OPTIND-1))

if [ $# -ne 2 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi


URL="$1"
DESTINATION_DIR="$2"


DESTINATION_DIR_ABS="$(readlink -f "$DESTINATION_DIR")"

if ! [ -d "$DESTINATION_DIR_ABS" ]; then
  abort "Destination directory \"$DESTINATION_DIR_ABS\" does not exist."
fi

NAME_ONLY="${URL##*/}"

FINAL_FILENAME="$DESTINATION_DIR_ABS/$NAME_ONLY"

if [ -f "$FINAL_FILENAME" ]; then
  echo "Skipping file \"$URL\", as it already exists in the destination directory."
  exit 0
fi

DOWNLOAD_IN_PROGRESS_PATH="$DESTINATION_DIR_ABS/$DOWNLOAD_IN_PROGRESS_SUBDIRNAME"

create_dir_if_not_exists "$DOWNLOAD_IN_PROGRESS_PATH"

TEMP_FILENAME="$DOWNLOAD_IN_PROGRESS_PATH/$NAME_ONLY"

echo "Downloading URL \"$URL\"..."

# Optional flags: --silent, --ftp-pasv, --ftp-method nocwd
curl --location --show-error --url "$URL" --output "$TEMP_FILENAME"


if $FULL_EXTRACTION; then
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

if [ $TAR_EXIT_CODE -ne 0 ]; then
  ERR_MSG="Downloaded archive file \"$URL\" failed the integrity test, see above for the detailed error message. "
  ERR_MSG="${ERR_MSG}The file may be corrupt, or curl may not have been able to follow a redirect properly. "
  ERR_MSG="${ERR_MSG}Try downloading the archive file from another location or mirror. "
  ERR_MSG="${ERR_MSG}You can inspect the corrupt file at \"$TEMP_FILENAME\"."
  abort "$ERR_MSG"
fi

mv "$TEMP_FILENAME" "$FINAL_FILENAME"

# echo "Finished downloading file \"$URL\" to \"$FINAL_FILENAME\"."

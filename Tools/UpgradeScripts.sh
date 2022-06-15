#!/bin/bash
#
# Copyright (c) 2018 - R. Diez - Licensed under the GNU AGPLv3.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


upgrade_script ()
{
  local -r SCRIPT_NAME="$1"
  local -r TOOLS_DIRNAME="$2"
  local -r DEST_DIRNAME="$3"

  local -r SCRIPT_FILENAME_SRC="$TOOLS_REPOSITORY/$TOOLS_DIRNAME/$SCRIPT_NAME"
  local -r SCRIPT_FILENAME_DEST="$GIT_REPOSITORY_BASE/$DEST_DIRNAME/$SCRIPT_NAME"

  if ! [ -x "$SCRIPT_FILENAME_DEST" ]; then
    abort "$SCRIPT_FILENAME_DEST does not exist or is not an executable file."
  fi

  if ! [ -x "$SCRIPT_FILENAME_SRC" ]; then
    abort "$SCRIPT_FILENAME_SRC does not exist or is not an executable file."
  fi


  set +o errexit

  cmp --quiet -- "$SCRIPT_FILENAME_SRC"  "$SCRIPT_FILENAME_DEST"

  local CMP_EXIT_CODE="$?"

  set -o errexit

  case "$CMP_EXIT_CODE" in
    0) echo "Already the latest version: $DEST_DIRNAME/$SCRIPT_NAME";;
    1) echo "Upgrading $DEST_DIRNAME/$SCRIPT_NAME ..."
       cp -- "$SCRIPT_FILENAME_SRC"  "$SCRIPT_FILENAME_DEST"
       UPGRADE_COUNT=$(( UPGRADE_COUNT + 1 ))
       ;;
    *) local MSG
       printf -v MSG "Comparing %q with %q failed."  "$SCRIPT_FILENAME_SRC"  "$SCRIPT_FILENAME_DEST"
       abort "$MSG";;
  esac
}


# ----- Entry point -----

GIT_REPOSITORY_BASE="$(readlink --canonicalize --verbose -- "..")"

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. Please specify the directory where the Tools repository is located."
fi

TOOLS_REPOSITORY="$1"

declare -i UPGRADE_COUNT=0

upgrade_script  "run-in-new-console.sh"  "RunInNewConsole"  "Tools"
upgrade_script  "RotateDir.pl"           "RotateDir"        "Tools"
upgrade_script  "DownloadTarball.sh"     "DownloadTarball"  "Toolchain/Tools"

echo "$UPGRADE_COUNT file(s) upgraded."

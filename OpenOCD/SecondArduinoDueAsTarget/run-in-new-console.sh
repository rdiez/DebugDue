#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

VERSION_NUMBER="1.00"
SCRIPT_NAME="run-in-new-console.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script runs the given shell command in a new console window.

You would normally use this tool to start interactive programs
like gdb. Another example would be to start a socat connection to
a serial port and leave it in the background for later use.

The command is passed as a string and is executed with "bash -c".

Syntax:
  $SCRIPT_NAME <options...> [--] "shell command to run"

Options:
 --terminal-type=xxx  Use the given terminal emulator, defaults to 'konsole'
                      (the only implemented type at the moment).
 --konsole-title="my title"
 --konsole-icon="icon name"  Icons are normally .png files on your system.
                             Examples are kcmkwm or applications-office.
 --konsole-no-close          Keep the console open after the command terminates.
                             Useful mainly to see why the command is failing.
 --konsole-discard-stderr    Sometimes Konsole spits out too many errors or warnings.
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Usage example, as you would manually type it:
  ./$SCRIPT_NAME "bash"

From a script you would normally use it like this:
  /path/$SCRIPT_NAME -- "\$CMD"

Exit status: 0 means success. Any other value means error.

If you wish to contribute code for other terminal emulators, please drop me a line.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2014 R. Diez

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


# Notes kept about an alternative method to set the console title with Konsole:
#
# Help text for --konsole-title:
#   Before using this option, manually create a Konsole
#   profile called "$SCRIPT_NAME", where the "Tab title
#   format" is set to %w . You may want to untick
#   global option "Show application name on the titlebar"
#   too.
#
# Code to set the window title with an escape sequence:
#  # Warning: The title does not get properly escaped here. If it contains console escape sequences,
#  #          this will break.
#  if [[ $KONSOLE_TITLE != "" ]]; then
#    CMD3+="printf \"%s\" \$'\\033]30;$KONSOLE_TITLE\\007' && "
#  fi
#
# Code to select the right Konsole profile:
#   KONSOLE_CMD+=" --profile $SCRIPT_NAME"


# ------- Entry point -------

# The way command-line arguments are parsed below was originally described on the following page,
# although I had to make a couple of amendments myself:
#   http://mywiki.wooledge.org/ComplexOptionParsing

# Use an associative array to declare how many arguments a long option expects.
# Long options that aren't listed in this way will have zero arguments by default.
declare -A MY_LONG_OPT_SPEC=([terminal-type]=1 [konsole-title]=1 [konsole-icon]=1)

# The first colon (':') means "use silent error reporting".
# The "-:" means an option can start with '-', which helps parse long options which start with "--".
MY_OPT_SPEC=":-:"

TERMINAL_TYPE="konsole"
KONSOLE_TITLE=""
KONSOLE_ICON=""
KONSOLE_NO_CLOSE=0
KONSOLE_DISCARD_SDTDERR=0

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
      terminal-type)
          if [[ ${OPTARG:-} = "" ]]; then
            abort "The --terminal-type option has an empty value.";
          fi
          TERMINAL_TYPE="$OPTARG"
          ;;
      konsole-title)
          if [[ ${OPTARG:-} = "" ]]; then
            abort "The --konsole-title option has an empty value.";
          fi
          KONSOLE_TITLE="$OPTARG"
          ;;
      konsole-icon)
          if [[ ${OPTARG:-} = "" ]]; then
            abort "The --konsole-icon option has an empty value.";
          fi
          KONSOLE_ICON="$OPTARG"
          ;;
      konsole-no-close)
          KONSOLE_NO_CLOSE=1
          ;;
      konsole-discard-stderr)
          KONSOLE_DISCARD_SDTDERR=1
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
      *)
          if [[ ${opt} = "?" ]]; then
            abort "Unknown command-line option \"$OPTARG\"."
          else
            abort "Unknown command-line option \"${opt}\"."
          fi
          ;;
    esac

    break
  done
done

case "${TERMINAL_TYPE}" in
  konsole) : ;;
  *) abort "Unknown terminal type \"$TERMINAL_TYPE\".";;
esac


shift $((OPTIND-1))
ARGS=("$@")

if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

CMD_ARG="${ARGS[0]}"

CMD2="$(printf "%q" "$CMD_ARG")"

CMD3="echo $CMD2 && eval $CMD2"

# Running the command with "sh -c" made it crash on my PC when pressing Ctrl+C under Kubuntu 14.04.
CMD4="$(printf "bash -c %q" "$CMD3")"

KONSOLE_CMD="konsole --nofork"

if [[ $KONSOLE_TITLE != "" ]]; then
  KONSOLE_CMD+=" -p tabtitle=\"$KONSOLE_TITLE\""
fi

if [[ $KONSOLE_ICON != "" ]]; then
  KONSOLE_CMD+=" -p Icon=$KONSOLE_ICON"
fi


if [ $KONSOLE_NO_CLOSE -ne 0 ]; then
  KONSOLE_CMD+=" --noclose"
fi

KONSOLE_CMD+=" -e $CMD4"

if [ $KONSOLE_DISCARD_SDTDERR -ne 0 ]; then
  KONSOLE_CMD+=" 2>/dev/null"
fi

if false; then
  echo "KONSOLE_CMD: $KONSOLE_CMD"
fi

eval "$KONSOLE_CMD"

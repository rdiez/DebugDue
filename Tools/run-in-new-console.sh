#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r VERSION_NUMBER="1.18"
declare -r SCRIPT_NAME="run-in-new-console.sh"

declare -r RUN_IN_NEW_CONSOLE_TERMINAL_TYPE_ENV_VAR_NAME="RUN_IN_NEW_CONSOLE_TERMINAL_TYPE"

declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014-2018 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script runs the given shell command in a new console window.

You would normally use this tool to launch interactive programs
like GDB on a separate window. Another example would be to start a socat connection
to a serial port and leave it in the background (on another window) for later use.
In these scenarios you probably want to start $SCRIPT_NAME as a background job
(in bash, append '&' to the whole $SCRIPT_NAME command).

The shell command to run is passed as a single string and is executed with "bash -c".

After running the user command, depending on the specified options and the success/failure outcome,
this script will prompt the user inside the new console window before closing it. The goal is to avoid
flashing an error message for a very short time and then closing the window immediately afterwards.
If the command fails, the user should have the chance to inspect the corresponding
error message at leisure.

The prompt asks the user to type "exit" and press Enter, which should be "stored in muscle memory"
for most users. Prompting for just Enter is not enough in my opinion, as the user will often press Enter
during a long-running command, either inadvertently or maybe to just visually separate text lines
in the command's output. Such Enter keypresses are usually forever remembered in the console,
so that they would make the console window immediately close when the command finishes much later on.

If you want to disable any prompting at the end, specify option --autoclose-on-error
and do not pass option --remain-open-on-success .

In the rare cases where the user runs a command that changes stdin settings, like "socat STDIO,nonblock=1"
does, the prompting may fail with error message "read error: 0: Resource temporarily unavailable".
I have not found an easy work-around for this issue. Sometimes, you may
be able to pipe /dev/null to the stdin of those programs which manipulate stdin flags,
so that they do not touch the real stdin after all.

Syntax:
  $SCRIPT_NAME <options...> [--] "shell command to run"

Options:
 --remain-open-on-success  The console should remain open after the command successfully
                           terminates (on a zero status code). Otherwise, the console closes
                           automatically if the command was successful.

 --autoclose-on-error  By default, the console remains open if an error occurred
                       (on non-zero status code). This helps troubleshoot the command to run.
                       This option closes the console after the command terminates with an error.

 --terminal-type=xxx  Use the given terminal emulator. Options are:
                      - 'auto' (the default)
                        Honours environment variable $RUN_IN_NEW_CONSOLE_TERMINAL_TYPE_ENV_VAR_NAME
                        if set (and not empty). Otherwise, it attempts to guess the current
                        desktop environment, in order to choose the most suitable terminal.
                        If that fails, it uses the first one found on the system from the available
                        terminal types below, in some arbitrary order hard-coded in this script,
                        subject to change without notice in any future versions.
                      - 'mate-terminal' for mate-terminal, the usual MATE Desktop terminal.
                      - 'konsole' for Konsole, the usual KDE terminal.
                      - 'xfce4-terminal' for xfce4-terminal, the usual Xfce terminal.
                      - 'xterm'

 --console-title="my title"

 --console-no-close          Always keep the console open after the command terminates,
                             but using some console-specific option.
                             Note that --remain-open-on-success is usually better option,
                             because the user can then close the console by typing with
                             the keyboard. Otherwise, you may be forced to resort to
                             the mouse in order to close the console window.
                             This option can also help debug $SCRIPT_NAME itself.
                             Not available on mate-terminal.

 --console-icon="icon name"  Icons are normally .png files on your system.
                             Examples are "kcmkwm" or "applications-office".
                             You can also specify the path to an image file (like a .png file).
                             This option does not work with mate-terminal.

 --console-discard-stderr    Sometimes Konsole spits out too many errors or warnings on the terminal
                             where $SCRIPT_NAME runs. For example, I have seen often D-Bus
                             warnings. This option keeps your terminal clean at the risk of missing
                             important error messages.

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


display_license ()
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
    terminal-type)
        if [[ $OPTARG = "" ]]; then
          abort "The --terminal-type option has an empty value.";
        fi
        TERMINAL_TYPE="$OPTARG"
        ;;
    console-title)
        if [[ $OPTARG = "" ]]; then
          abort "The --console-title option has an empty value.";
        fi
        CONSOLE_TITLE="$OPTARG"
        ;;
    console-icon)
        if [[ $OPTARG = "" ]]; then
          abort "The --console-icon option has an empty value.";
        fi
        CONSOLE_ICON="$OPTARG"
        ;;
    console-no-close)
        CONSOLE_NO_CLOSE=1
        ;;
    remain-open-on-success)
        REMAIN_OPEN_ON_SUCCESS=1
        ;;
    autoclose-on-error)
        AUTOCLOSE_ON_ERROR=1
        ;;
    console-discard-stderr)
        CONSOLE_DISCARD_STDERR=1
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


is_tool_installed ()
{
  if type "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


declare -r PROGRAM_KONSOLE="konsole"
declare -r PROGRAM_XFCE4_TERMINAL="xfce4-terminal"
declare -r PROGRAM_MATE_TERMINAL="mate-terminal"
declare -r PROGRAM_XTERM="xterm"

automatically_determine_terminal_type ()
{
  case "${XDG_CURRENT_DESKTOP:-}" in
    KDE)   if is_tool_installed "$PROGRAM_KONSOLE"; then
             USE_KONSOLE=true
             return
           fi;;

    XFCE)  if is_tool_installed "$PROGRAM_XFCE4_TERMINAL"; then
             USE_XFCE4_TERMINAL=true
             return
           fi;;

    MATE)  if is_tool_installed "$PROGRAM_MATE_TERMINAL"; then
             USE_MATE_TERMINAL=true
             return
           fi;;

    XTERM)  if is_tool_installed "$PROGRAM_XTERM"; then
             USE_XTERM=true
             return
           fi;;
    *) ;;
  esac

  # The order of preference for these checks is arbitrary.
  # The documentation warns the user that it can change at any time.

  if is_tool_installed "$PROGRAM_MATE_TERMINAL"; then
    USE_MATE_TERMINAL=true
    return
  fi

  if is_tool_installed "$PROGRAM_KONSOLE"; then
    USE_KONSOLE=true
    return
  fi

  if is_tool_installed "$PROGRAM_XFCE4_TERMINAL"; then
    USE_XFCE4_TERMINAL=true
    return
  fi

  if is_tool_installed "$PROGRAM_XTERM"; then
    USE_XTERM=true
    return
  fi

  abort "No suitable terminal program found."
}


# ------- Entry point -------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [console-discard-stderr]=0 )
USER_LONG_OPTIONS_SPEC+=( [console-no-close]=0 )
USER_LONG_OPTIONS_SPEC+=( [terminal-type]=1 )
USER_LONG_OPTIONS_SPEC+=( [console-title]=1 )
USER_LONG_OPTIONS_SPEC+=( [console-icon]=1 )
USER_LONG_OPTIONS_SPEC+=( [remain-open-on-success]=0 )
USER_LONG_OPTIONS_SPEC+=( [autoclose-on-error]=0 )

TERMINAL_TYPE="auto"
CONSOLE_TITLE=""
CONSOLE_ICON=""
CONSOLE_NO_CLOSE=0
REMAIN_OPEN_ON_SUCCESS=0
AUTOCLOSE_ON_ERROR=0
CONSOLE_DISCARD_STDERR=0

parse_command_line_arguments "$@"

USE_MATE_TERMINAL=false
USE_KONSOLE=false
USE_XFCE4_TERMINAL=false
USE_XTERM=false


if [[ $TERMINAL_TYPE == auto ]]; then
  TERMINAL_TYPE="${!RUN_IN_NEW_CONSOLE_TERMINAL_TYPE_ENV_VAR_NAME:-auto}"
fi

case "${TERMINAL_TYPE}" in
  auto)           automatically_determine_terminal_type;;
  mate-terminal)  USE_MATE_TERMINAL=true;;
  konsole)        USE_KONSOLE=true;;
  xfce4-terminal) USE_XFCE4_TERMINAL=true;;
  xterm)          USE_XTERM=true;;
  *) abort "Unknown terminal type \"$TERMINAL_TYPE\".";;
esac

if [ ${#ARGS[@]} -ne 1 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

CMD_ARG="${ARGS[0]}"

printf -v QUOTED_CMD_ARG "%q" "$CMD_ARG"

# We promised the user that we would run his command with "bash -c", so do not concatenate the command string
# or use 'eval' here, but issue a "bash -c" as promised.
CMD3="echo $QUOTED_CMD_ARG && echo && bash -c $QUOTED_CMD_ARG"


if false; then
  echo "REMAIN_OPEN_ON_SUCCESS: $REMAIN_OPEN_ON_SUCCESS"
  echo "AUTOCLOSE_ON_ERROR: $AUTOCLOSE_ON_ERROR"
fi

# Some programs, like 'socat', do not terminate their error messages with an end-of-line character. Therefore,
# if we are going to prompt the user, always leave an empty line, just in case.
PRINT_EMPTY_LINE="echo"

# When prompting, the 'read' command can fail, see comment about "read error: 0: Resource temporarily unavailable" above.
ENABLE_ERROR_CHECKING="set -o errexit && set -o nounset && set -o pipefail"

if [ $REMAIN_OPEN_ON_SUCCESS -eq 0 ]; then

  if [ $AUTOCLOSE_ON_ERROR -eq 0 ]; then
    CMD3+="; EXIT_CODE=\"\$?\" && $PRINT_EMPTY_LINE && $ENABLE_ERROR_CHECKING && if [ \$EXIT_CODE -ne 0 ]; then while true; do read -p \"Process failed with status code \$EXIT_CODE. Type 'exit' and press Enter to exit: \" USER_INPUT; if [[ \${USER_INPUT^^} = \"EXIT\" ]]; then break; fi; done; fi"
  fi

else

  if [ $AUTOCLOSE_ON_ERROR -eq 0 ]; then
    CMD3+="; EXIT_CODE=\"\$?\" && $PRINT_EMPTY_LINE && $ENABLE_ERROR_CHECKING && while true; do read -p \"Process terminated with status code \$EXIT_CODE. Type 'exit' and press Enter to exit: \" USER_INPUT; if [[ \${USER_INPUT^^} = \"EXIT\" ]]; then break; fi; done"
  else
    CMD3+="; EXIT_CODE=\"\$?\" && $PRINT_EMPTY_LINE && $ENABLE_ERROR_CHECKING && if [ \$EXIT_CODE -eq 0 ]; then while true; do read -p \"Process terminated with status code \$EXIT_CODE. Type 'exit' and press Enter to exit: \" USER_INPUT; if [[ \${USER_INPUT^^} = \"EXIT\" ]]; then break; fi; done; fi"
  fi

fi

printf -v CMD4 "bash -c %q" "$CMD3"

printf -v CONSOLE_ICON_QUOTED "%q" "$CONSOLE_ICON"
printf -v CONSOLE_TITLE_QUOTED "%q" "$CONSOLE_TITLE"


if $USE_KONSOLE; then

  printf -v CONSOLE_CMD "%q --nofork" "$PROGRAM_KONSOLE"

  # Notes kept about an alternative method to set the console title with Konsole:
  #
  # Before using this option, manually create a Konsole
  # profile called "$SCRIPT_NAME", where the "Tab title
  # format" is set to %w . You may want to untick
  # global option "Show application name on the titlebar"  too.
  #
  # Code to select the right Konsole profile:
  #   CONSOLE_CMD+=" --profile $SCRIPT_NAME"
  #
  # Code to set the window title with an escape sequence:
  #  # Warning: The title does not get properly escaped here. If it contains console escape sequences,
  #  #          this will break.
  #  if [[ $CONSOLE_TITLE != "" ]]; then
  #    Later note: it is better to use printf -v CONSOLE_TITLE_QUOTED beforehand.
  #    CMD3+="printf \"%s\" \$'\\033]30;$CONSOLE_TITLE\\007' && "
  #  fi

  if [[ $CONSOLE_TITLE != "" ]]; then
    CONSOLE_CMD+=" -p tabtitle=$CONSOLE_TITLE_QUOTED"
  fi

  if [[ $CONSOLE_ICON != "" ]]; then
    CONSOLE_CMD+=" -p Icon=$CONSOLE_ICON_QUOTED"
  fi

  if [ $CONSOLE_NO_CLOSE -ne 0 ]; then
    CONSOLE_CMD+=" --noclose"
  fi

  CONSOLE_CMD+=" -e $CMD4"

fi


if $USE_XFCE4_TERMINAL; then

  printf -v CONSOLE_CMD "%q" "$PROGRAM_XFCE4_TERMINAL"

  # Whether "xfce4-terminal --command" blocks, depends on whether there was already a running
  # instance of xfce4-terminal on the current session. I have reported this behaviour as a bug:
  #   https://bugzilla.xfce.org/show_bug.cgi?id=14544
  #
  # Adding option --disable-server seems to fix it. However, this option is documented as
  # "Do not register with the D-BUS session message bus", which is apparently unrelated to
  # blocking, so I am not sure what other things will be breaking by disabling this D-Bus feature.
  CONSOLE_CMD+=" --disable-server"

  if [[ $CONSOLE_TITLE != "" ]]; then
    CONSOLE_CMD+=" --title=$CONSOLE_TITLE_QUOTED"
  fi

  if [[ $CONSOLE_ICON != "" ]]; then
    CONSOLE_CMD+=" --icon=$CONSOLE_ICON_QUOTED"
  fi

  if [ $CONSOLE_NO_CLOSE -ne 0 ]; then
    CONSOLE_CMD+=" --hold"
  fi

  printf -v CMD5 "%q" "$CMD4"

  CONSOLE_CMD+=" --command=$CMD5"

fi


if $USE_MATE_TERMINAL; then

  printf -v CONSOLE_CMD "%q" "$PROGRAM_MATE_TERMINAL"

  # Whether "mate-terminal --command" blocks, depends on whether there was already a running
  # instance of mate-terminal on the current session. I have reported this behaviour as a bug:
  #   https://github.com/mate-desktop/mate-terminal/issues/248
  #
  # Adding option --disable-factory seems to fix it. However, this option is documented as
  # "Do not register with the activation nameserver, do not re-use an active terminal",
  # which is apparently unrelated to blocking, so I am not sure what other things will be
  # breaking by disabling this "activation nameserver" feature.
  CONSOLE_CMD+=" --disable-factory"

  if [[ $CONSOLE_TITLE != "" ]]; then
    CONSOLE_CMD+=" --title=$CONSOLE_TITLE_QUOTED"
  fi

  if [[ $CONSOLE_ICON != "" ]]; then
    # Unfortunately, mate-terminal does not support --icon anymore.
    # I submitted a request to get this option back:
    #   https://github.com/mate-desktop/mate-terminal/issues/246
    echo "Warning: $PROGRAM_MATE_TERMINAL does not support setting an application icon with option --console-icon ." >&2
  fi

  if [ $CONSOLE_NO_CLOSE -ne 0 ]; then
    abort "$PROGRAM_MATE_TERMINAL does not support option --console-no-close ."
  fi

  printf -v CMD5 "%q" "$CMD4"

  CONSOLE_CMD+=" --command=$CMD5"

fi


if $USE_XTERM; then

  printf -v CONSOLE_CMD "%q" "$PROGRAM_XTERM"

  if [[ $CONSOLE_TITLE != "" ]]; then
    CONSOLE_CMD+=" -title $CONSOLE_TITLE_QUOTED"
  fi

  if [[ $CONSOLE_ICON != "" ]]; then
    # CONSOLE_CMD+=" -xrm XTerm.iconName:\\ $CONSOLE_ICON_QUOTED"
    # CONSOLE_CMD+=" -n $CONSOLE_ICON_QUOTED"
    echo "Warning: I could not get $PROGRAM_XTERM to honour the icon set with option --console-icon ." >&2
  fi

  if [ $CONSOLE_NO_CLOSE -ne 0 ]; then
    CONSOLE_CMD+=" -hold"
  fi

  printf -v CMD5 "%q" "$CMD4"

  # Note that the -e option must be the last one.
  CONSOLE_CMD+=" -e $CMD5"

fi


if [ $CONSOLE_DISCARD_STDERR -ne 0 ]; then
  CONSOLE_CMD+=" 2>/dev/null"
fi


if false; then
  echo "CONSOLE_CMD: $CONSOLE_CMD"
fi

eval "$CONSOLE_CMD"

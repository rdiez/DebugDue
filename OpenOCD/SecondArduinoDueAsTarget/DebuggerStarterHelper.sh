#!/bin/bash

# Copyright (c) 2014-2020 R. Diez - Licensed under the GNU AGPLv3 - see companion script JtagDueBuilder.sh for more information.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


add_gdb_arg ()
{
  GDB_CMD+=" $1"
}


add_gdb_echo_cmd ()
{
  local MSG="$1"

  local QUOTED
  printf -v QUOTED "%q" "$MSG"
  add_gdb_arg "--eval-command=\"echo > $QUOTED\\n\""
}


add_gdb_cmd ()
{
  local CMD="$1"

  add_gdb_echo_cmd "$CMD"
  local QUOTED
  printf -v QUOTED "%q" "$CMD"
  add_gdb_arg "--eval-command=$QUOTED"
}


add_gdb_cmd_no_echo ()
{
  local CMD="$1"

  local QUOTED
  printf -v QUOTED "%q" "$CMD"
  add_gdb_arg "--eval-command=$QUOTED"
}


process_command_line_argument ()
{
  case "$OPTION_NAME" in

    debug-from-the-start) DEBUG_FROM_THE_START_SPECIFIED=true;;

    add-breakpoint)
        if [[ $OPTARG = "" ]]; then
          abort "The --add-breakpoint option has an empty value."
        fi
        BREAKPOINTS+=("$OPTARG")
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


# ------- Entry point -------

GIT_REPOSITORY_BASE="$(readlink --canonicalize --verbose -- "../..")"

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [add-breakpoint]=1 )
USER_LONG_OPTIONS_SPEC+=( [debug-from-the-start]=0 )

DEBUG_FROM_THE_START_SPECIFIED=false
declare -a BREAKPOINTS=()

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} != 4 )); then
  abort "Invalid number of command-line arguments."
fi

TOOLCHAIN_PATH="${ARGS[0]}"
ELF_FILE_PATH="${ARGS[1]}"
TARGET_TYPE="${ARGS[2]}"
DEBUGGER_TYPE="${ARGS[3]}"

case "$DEBUGGER_TYPE" in
  ddd) : ;;
  gdb) : ;;
  *) abort "Unknown debugger type \"$DEBUGGER_TYPE\"."
esac


# ------ Start GDB in a separate console ------

TARGET_ARCH="arm-none-eabi"

GDB_PATH="$TOOLCHAIN_PATH/bin/$TARGET_ARCH-gdb"

GDB_CMD=""

if [[ $DEBUGGER_TYPE = "ddd" ]]; then

  GDB_CMD+="ddd --debugger \"$GDB_PATH\""

  # If we don't turn confirmation off for dangerous operations, then we cannot just close
  # DDD's window, we have to click on an OK button first. It's a shame that there is no option
  # in DDD to suppress confirmation on exit.
  add_gdb_cmd "set confirm off"

else

  GDB_CMD+="\"$GDB_PATH\""

  # Whether you like the TUI mode is your personal preference.
  #
  # In TUI mode, you cannot scroll the command window to see previous output. This is a serious inconvenience,
  # so you may need to disable TUI every now and then.
  #
  # Some GDB versions may have been built without TUI support.
  #
  # Disabling TUI from inside GDB with command "tui disable" makes my GDB 9.2 suddenly quit.
  declare -r ENABLE_TUI=true

  if $ENABLE_TUI; then
    add_gdb_arg "--tui"
  fi

  # If the new console window happens to open with a small size, you'll get a "---Type <return> to continue, or q <return> to quit---"
  # prompt on start-up when GDB prints its version number and configuration options. Switch "--quiet" tries to minimize the problem.
  add_gdb_arg "--quiet"

  # GDB's constant confirmation prompts get on my nerves.
  add_gdb_cmd "set confirm off"

  add_gdb_cmd "set pagination off"

  # Command "focus cmd" automatically turns TUI on.
  if $ENABLE_TUI; then
    add_gdb_cmd "focus cmd"
  fi

  add_gdb_cmd "set print pretty on"

fi


case "$TARGET_TYPE" in
  ArduinoDue) add_gdb_arg "--command=\"arduino-due-gdb-cmds.txt\"" ;;
  QEMU)       add_gdb_arg "--command=\"qemu-gdb-cmds.txt\"" ;;
  *) abort "Unknown target type \"$TARGET_TYPE\"."
esac


add_gdb_cmd "target remote :3333"

if (( ${#BREAKPOINTS[*]} > 0 )); then
  for BP in "${BREAKPOINTS[@]}"; do
    add_gdb_cmd "hbreak $BP"
  done
fi

if $DEBUG_FROM_THE_START_SPECIFIED; then
  add_gdb_cmd "myhaltafterreset"
else
  add_gdb_cmd "myreset"
fi

# If GDB cannot find the .elf file, it will print an error, but it will not stop.
# Therefore, manually check here whether the file does exist.
if [ ! -f "$ELF_FILE_PATH" ]; then
  abort "Cannot find the ELF file \"$ELF_FILE_PATH\"."
fi

add_gdb_arg "\"$ELF_FILE_PATH\""

if [[ $DEBUGGER_TYPE = "ddd" ]]; then

  echo
  echo "Starting DDD with command:"
  echo "$GDB_CMD"
  echo

  eval "$GDB_CMD"

else

  NEW_CONSOLE_CMD="$GIT_REPOSITORY_BASE/Tools/run-in-new-console.sh"
  NEW_CONSOLE_CMD+=" --console-discard-stderr"
  NEW_CONSOLE_CMD+=" --console-icon=audio-card"
  NEW_CONSOLE_CMD+=" --console-title=\"Arduino Due GDB\""
  NEW_CONSOLE_CMD+=" --"
  NEW_CONSOLE_CMD+=" $(printf "%q" "$GDB_CMD")"

  echo
  echo "The GDB command is:"
  echo "$GDB_CMD"
  echo

  echo "Starting GDB in a new console with command:"
  echo "$NEW_CONSOLE_CMD"
  echo

  eval "$NEW_CONSOLE_CMD"

fi

exit $EXIT_CODE_SUCCESS

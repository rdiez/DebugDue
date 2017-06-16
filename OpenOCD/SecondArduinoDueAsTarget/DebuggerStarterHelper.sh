#!/bin/bash

# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3 - see companion script JtagDueBuilder.sh for more information.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
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


read_command_line_switches ()
{
  # The way command-line arguments are parsed below was originally described on the following page,
  # although I had to make a couple of amendments myself:
  #   http://mywiki.wooledge.org/ComplexOptionParsing

  # Use an associative array to declare how many arguments a long option expects.
  # Long options that aren't listed in this way will have zero arguments by default.
  local -A MY_LONG_OPT_SPEC=([add-breakpoint]=1)

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  local MY_OPT_SPEC=":-:"

  DEBUG_FROM_THE_START_SPECIFIED=false
  declare -ag BREAKPOINTS=()

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

        debug-from-the-start) DEBUG_FROM_THE_START_SPECIFIED=true;;

        add-breakpoint)
            if [[ ${OPTARG:-} = "" ]]; then
              abort "The --add-breakpoint option has an empty value."
            fi
            BREAKPOINTS+=("$OPTARG")
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

  shift $((OPTIND-1))

  if false; then
    echo "Arguments:"
    for i; do 
      echo "$i"
   done
  fi

  if [ $# != 3 ]; then
    abort "Invalid command-line arguments."
  fi

  TOOLCHAIN_PATH="$1"
  ELF_FILE_PATH="$2"
  DEBUGGER_TYPE="$3"
}


# ------- Entry point -------

read_command_line_switches "$@"

case "$DEBUGGER_TYPE" in
  ddd) : ;;
  gdb) : ;;
  *) abort "Unknown debugger type \"$DEBUGGER_TYPE\"."
esac


# ------ Start GDB in a separate KDE Konsole ------

TARGET_ARCH="arm-none-eabi"

GDB_PATH="$TOOLCHAIN_PATH/bin/$TARGET_ARCH-gdb"

if [[ $DEBUGGER_TYPE = "ddd" ]]; then

  GDB_CMD="ddd --debugger \"$GDB_PATH\""

  # If we don't turn confirmation off for dangerous operations, then we cannot just close
  # DDD's window, we have to click on an OK button first. It's a shame that there is no option
  # in DDD to suppress confirmation on exit.
  add_gdb_cmd "set confirm off"

else

  GDB_CMD="\"$GDB_PATH\""

  # Whether you like the TUI mode is your personal preference.
  add_gdb_arg "--tui"

  # If the new console window happens to open with a small size, you'll get a "---Type <return> to continue, or q <return> to quit---"
  # prompt on start-up when GDB prints its version number and configuration options. Switch "--quiet" tries to minimize the problem.
  add_gdb_arg "--quiet"

  # GDB's constant confirmation prompts get on my nerves.
  add_gdb_cmd "set confirm off"

  add_gdb_cmd "set pagination off"

  add_gdb_cmd "focus cmd"

  add_gdb_cmd "set print pretty on"

fi

add_gdb_cmd "target remote :3333"

if (( ${#BREAKPOINTS[*]} > 0 )); then
  for BP in "${BREAKPOINTS[@]}"; do
    add_gdb_cmd "hbreak $BP"
  done
fi

if $DEBUG_FROM_THE_START_SPECIFIED; then
  add_gdb_cmd "monitor my_reset_and_halt"

  # Force GDB to update its register cache. Otherwise, the right values are
  # shown only after the first 'step' command.
  add_gdb_cmd flushregs

  add_gdb_echo_cmd "Stopped as soon as possible upon start-up."
else
  add_gdb_cmd "monitor my_reset_and_halt"
  add_gdb_cmd "cont"
fi

# If GDB cannot find the .elf file, it will print an error, but it will not stop.
# Therefore, manually check here whether the file does exist.
if [ ! -f "$ELF_FILE_PATH" ]; then
  abort "Cannot find the ELF file \"$ELF_FILE_PATH\"."
fi

add_gdb_arg "\"$ELF_FILE_PATH\""

if [[ $DEBUGGER_TYPE = "ddd" ]]; then
  echo "Starting DDD in the background with: $GDB_CMD"
  eval "$GDB_CMD &"
else
  NEW_CONSOLE_CMD="./run-in-new-console.sh"
  NEW_CONSOLE_CMD+=" --konsole-discard-stderr"
  NEW_CONSOLE_CMD+=" --konsole-icon=kcmkwm"
  NEW_CONSOLE_CMD+=" --konsole-title=\"Arduino Due GDB\""
  NEW_CONSOLE_CMD+=" --"
  NEW_CONSOLE_CMD+=" $(printf "%q" "$GDB_CMD")"

  echo "Starting GDB in new console with: $NEW_CONSOLE_CMD"
  eval "$NEW_CONSOLE_CMD &"
fi

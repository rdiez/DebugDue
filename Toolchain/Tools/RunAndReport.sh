#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.06"


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


read_uptime_as_integer ()
{
  local PROC_UPTIME_CONTENTS
  PROC_UPTIME_CONTENTS="$(</proc/uptime)"

  local PROC_UPTIME_COMPONENTS
  IFS=$' \t' read -r -a PROC_UPTIME_COMPONENTS <<< "$PROC_UPTIME_CONTENTS"

  local UPTIME_AS_FLOATING_POINT=${PROC_UPTIME_COMPONENTS[0]}

  # The /proc/uptime format is not exactly documented, so I am not sure whether
  # there will always be a decimal part. Therefore, capture the integer part
  # of a value like "123" or "123.45".
  # I hope /proc/uptime never yields a value like ".12" or "12.", because
  # the following code does not cope with those.

  local REGEXP="^([0-9]+)(\\.[0-9]+)?\$"

  if ! [[ $UPTIME_AS_FLOATING_POINT =~ $REGEXP ]]; then
    abort "Error parsing this uptime value: $UPTIME_AS_FLOATING_POINT"
  fi

  UPTIME=${BASH_REMATCH[1]}
}


get_human_friendly_elapsed_time ()
{
  local -i SECONDS="$1"

  if (( SECONDS <= 59 )); then
    ELAPSED_TIME_STR="$SECONDS seconds"
    return
  fi

  local -i V="$SECONDS"

  ELAPSED_TIME_STR="$(( V % 60 )) seconds"

  V="$(( V / 60 ))"

  ELAPSED_TIME_STR="$(( V % 60 )) minutes, $ELAPSED_TIME_STR"

  V="$(( V / 60 ))"

  if (( V > 0 )); then
    ELAPSED_TIME_STR="$V hours, $ELAPSED_TIME_STR"
  fi

  printf -v ELAPSED_TIME_STR  "%s (%'d seconds)"  "$ELAPSED_TIME_STR"  "$SECONDS"
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2011-2022 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool runs a command with Bash, saves its stdout and stderr output and generates a report file."
  echo
  echo "Use companion tool GenerateBuildReport.pl to generate an HTML table with the succeeded/failed status of all commands run. You can then drill-down to each command's output."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> <programmatic name>  <user-friendly name>  filename.log  filename.report  command <command arguments...>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo " --quiet    Suppress printing command banner, exit code and elapsed time."
  echo " --hide-from-report-if-successful  Sometimes, a task is only worth reporting when it fails."
  echo " --copy-stderr=filename  Copies stderr to a separate file."
  echo "                         This uses a separate 'tee' process for stderr, so the order of"
  echo "                         stdout and stderr mixing in the final log file may change a little."
  echo "                         This separate file does not appear in the report (no yet implemented)."
  echo
  echo "Usage examples:"
  echo "  ./$SCRIPT_NAME -- test1  \"Test 1\"  test1.log  test1.report  echo \"Test 1 output.\""
  echo
  echo "Exit status: Same as the command executed. Note that this script assumes that 0 means success."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license ()
{
cat - <<EOF

Copyright (c) 2011-2022 R. Diez

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
    hide-from-report-if-successful)
        HIDE_FROM_REPORT_IF_SUCCESSFUL=true
        ;;
    quiet)
        QUIET=true
        ;;
    copy-stderr)
        if [[ $OPTARG = "" ]]; then
          abort "Option --copy-stderr has an empty value.";
        fi
        STDERR_COPY_FILENAME="$OPTARG"
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


# ------- Entry point -------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [hide-from-report-if-successful]=0 )
USER_LONG_OPTIONS_SPEC+=( [quiet]=0 )
USER_LONG_OPTIONS_SPEC+=( [copy-stderr]=1 )

HIDE_FROM_REPORT_IF_SUCCESSFUL=false
QUIET=false
STDERR_COPY_FILENAME=""

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} < 5 )); then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

PROGRAMMATIC_NAME="${ARGS[0]}"
USER_FRIENDLY_NAME="${ARGS[1]}"
LOG_FILENAME="${ARGS[2]}"
REPORT_FILENAME="${ARGS[3]}"

ARGS=( "${ARGS[@]:4}" )

printf  -v USER_CMD  " %q"  "${ARGS[@]}"
USER_CMD="${USER_CMD:1}"  # Remove the leading space.


read_uptime_as_integer
declare -r START_UPTIME="$UPTIME"

START_TIME="$(date '+%s')"
START_TIME_LOCAL="$(date --date=@"$START_TIME" '+%Y-%m-%d %T %z')"
START_TIME_UTC="$(date --date=@"$START_TIME" '+%Y-%m-%d %T %z' --utc)"

{
  # Print the executed command with proper quoting, so that the user can
  # copy-and-paste the command from the log file and expect it to work.
  echo "Log file for \"$USER_FRIENDLY_NAME\""
  printf "Command: %s" "$USER_CMD"
  echo

  echo "Current directory: $PWD"
  echo "This file's character encoding: ${LANG:-(unknown, the LANG environment variable is not set)}"
  echo "Start time:  Local: $START_TIME_LOCAL, UTC: $START_TIME_UTC"
  echo "Environment variables:"
  export
  echo
} >"$LOG_FILENAME"

if ! $QUIET; then
  printf 'Running command: %s\n\n' "$USER_CMD"
fi

set +o errexit

if [ -z "$STDERR_COPY_FILENAME" ]; then

  {
    eval "$USER_CMD"
  } 2>&1 | tee --append -- "$LOG_FILENAME"

else

  # Bash makes it hard to determine whether the child process from a 'process substitution' fails.
  # The most common cause of failure with 'tee' is not being able to create or write to the
  # separate stderr file, so doing it once beforehand should catch most errors.
  # This command creates the file, or truncates it if it already exists.
  echo -n "" >"$STDERR_COPY_FILENAME"

  {
    eval "$USER_CMD"
  } 2> >(tee -- "$STDERR_COPY_FILENAME") | tee --append -- "$LOG_FILENAME"

fi

declare -a -r CAPTURED_PIPESTATUS=( "${PIPESTATUS[@]}" )

set -o errexit

declare -i -r EXPECTED_PIPE_ELEM_COUNT=2

if (( ${#CAPTURED_PIPESTATUS[*]} != EXPECTED_PIPE_ELEM_COUNT )); then
  abort "Internal error: Pipeline status element count of ${#CAPTURED_PIPESTATUS[*]} instead of the expected $EXPECTED_PIPE_ELEM_COUNT."
fi

if (( CAPTURED_PIPESTATUS[1] != 0 )); then
  abort "tee failed with exit code ${CAPTURED_PIPESTATUS[1]}"
fi

declare -r -i CMD_EXIT_CODE="${CAPTURED_PIPESTATUS[0]}"

FINISH_TIME="$(date '+%s')"
FINISH_TIME_LOCAL="$(date --date=@"$FINISH_TIME" '+%Y-%m-%d %T %z')"
FINISH_TIME_UTC="$(date --date=@"$FINISH_TIME" '+%Y-%m-%d %T %z' --utc)"

read_uptime_as_integer
declare -r FINISH_UPTIME="$UPTIME"

ELAPSED_SECONDS="$((FINISH_UPTIME - START_UPTIME))"

get_human_friendly_elapsed_time "$ELAPSED_SECONDS"

if (( CMD_EXIT_CODE == 0 )); then
  FINISHED_MSG="The command finished successfully (exit code 0)."
else
  FINISHED_MSG="The command failed with exit code $CMD_EXIT_CODE."
fi

{
  echo
  echo "End of log file for \"$USER_FRIENDLY_NAME\""
  echo "Finish time: Local: $FINISH_TIME_LOCAL, UTC: $FINISH_TIME_UTC"
  echo "Elapsed time: $ELAPSED_TIME_STR"
  echo "$FINISHED_MSG"
} >>"$LOG_FILENAME"

{
  echo "ReportFormatVersion=1"
  echo "UserFriendlyName=$USER_FRIENDLY_NAME"
  echo "ProgrammaticName=$PROGRAMMATIC_NAME"
  echo "ExitCode=$CMD_EXIT_CODE"

  if $HIDE_FROM_REPORT_IF_SUCCESSFUL; then
    echo "HideFromReportIfSuccessful=true"
  else
    echo "HideFromReportIfSuccessful=false"
  fi

  echo "LogFile=$LOG_FILENAME"

  echo "StartTimeLocal=$START_TIME_LOCAL"
  echo "StartTimeUTC=$START_TIME_UTC"

  echo "FinishTimeLocal=$FINISH_TIME_LOCAL"
  echo "FinishTimeUTC=$FINISH_TIME_UTC"

  echo "ElapsedSeconds=$ELAPSED_SECONDS"
} >"$REPORT_FILENAME"

if ! $QUIET; then
  echo
  echo "$FINISHED_MSG"
  echo "Elapsed time: $ELAPSED_TIME_STR"

  if false; then
    echo "Note that log file \"$LOG_FILENAME\" has been created."
  fi
fi

exit "$CMD_EXIT_CODE"

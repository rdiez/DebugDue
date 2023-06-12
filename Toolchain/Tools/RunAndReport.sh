#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.08"


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


#------------------------------------------------------------------------
#
# Formats a duration as a human-friendly string, with hours, minutes, etc.
#

declare -r -i SECONDS_IN_MINUTE=60
declare -r -i SECONDS_IN_HOUR=$(( 60 * SECONDS_IN_MINUTE ))
declare -r -i SECONDS_IN_DAY=$((  24 * SECONDS_IN_HOUR   ))
declare -r -i SECONDS_IN_WEEK=$((  7 * SECONDS_IN_DAY    ))

format_human_friendly_duration ()
{
  local -i TOTAL_SECONDS="$1"  # Number of seconds as an integer.

  if (( TOTAL_SECONDS < 0 )); then
    abort "Invalid number of seconds."
  fi

  if (( TOTAL_SECONDS < SECONDS_IN_MINUTE )); then

    ELAPSED_TIME_STR="$TOTAL_SECONDS second"

    if (( TOTAL_SECONDS != 1 )); then
      ELAPSED_TIME_STR+="s"
    fi

    return

  fi

  # At this point, the message will not consist of just a number of seconds.
  # The total number of seconds will be appended to the message inside parenthesis.

  local -i SECONDS=$TOTAL_SECONDS

  local -i MINUTES=$(( SECONDS / 60 ))
           SECONDS=$(( SECONDS % 60 ))

  # Possible optimisation: Do not consider higher units if the number of minutes <= 59,
  #                        and the same later on for hours etc.

  local -i HOURS=$(( MINUTES / 60 ))
         MINUTES=$(( MINUTES % 60 ))

  local -i DAYS=$((  HOURS   / 24 ))
          HOURS=$((  HOURS   % 24 ))

  local -i WEEKS=$(( DAYS    /  7 ))
            DAYS=$(( DAYS    %  7 ))

  # Months are problematic in a duration, because not all months have the same number of days.

  local -a MESSAGE_COMPONENTS
  local TMP

  if (( WEEKS > 0 )); then

    # Note the ' in %'d for the thousands separators. There could be 1,000 weeks or more.

    printf -v TMP "%'d week" "$WEEKS"

    if (( WEEKS != 1 )); then
      TMP+="s"
    fi

    MESSAGE_COMPONENTS+=( "$TMP" )
  fi

  if (( DAYS > 0 )); then

    printf -v TMP "%d day" "$DAYS"

    if (( DAYS != 1 )); then
      TMP+="s"
    fi

    MESSAGE_COMPONENTS+=( "$TMP" )
  fi

  if (( HOURS > 0 )); then

    printf -v TMP "%d hour" "$HOURS"

    if (( HOURS != 1 )); then
      TMP+="s"
    fi

    MESSAGE_COMPONENTS+=( "$TMP" )

  fi

  if (( MINUTES > 0 )); then

    printf -v TMP "%d minute" "$MINUTES"

    if (( MINUTES != 1 )); then
      TMP+="s"
    fi

    MESSAGE_COMPONENTS+=( "$TMP" )

  fi

  if (( SECONDS > 0 )); then

    printf -v TMP "%d second" "$SECONDS"

    if (( SECONDS != 1 )); then
      TMP+="s"
    fi

    MESSAGE_COMPONENTS+=( "$TMP" )

  fi


  local -i MESSAGE_COMPONENT_COUNT="${#MESSAGE_COMPONENTS[@]}"

  if (( MESSAGE_COMPONENT_COUNT < 2 )); then

    ELAPSED_TIME_STR="${MESSAGE_COMPONENTS[0]}"

  else

    TMP=""
    TMP+="${MESSAGE_COMPONENTS[$(( MESSAGE_COMPONENT_COUNT - 2 ))]}"
    TMP+=" and "
    TMP+="${MESSAGE_COMPONENTS[$(( MESSAGE_COMPONENT_COUNT - 1 ))]}"

    if (( MESSAGE_COMPONENT_COUNT == 2 )); then

      ELAPSED_TIME_STR="$TMP"

    else

      printf -v ELAPSED_TIME_STR \
             "%s, " \
             "${MESSAGE_COMPONENTS[@]:0:$(( MESSAGE_COMPONENT_COUNT - 2 ))}"

      ELAPSED_TIME_STR+="$TMP"

    fi

  fi

  printf -v TMP \
         " (%'d seconds)" \
         "$TOTAL_SECONDS"

  ELAPSED_TIME_STR+="$TMP"
}


fhfd_test ()
{
  local -i NUMBER_OF_SECONDS="$1"
  local    EXPECTED_RESULT="$2"

  FHFD_TEST_CASE_NUMBER=$(( FHFD_TEST_CASE_NUMBER + 1 ))

  echo "Test $FHFD_TEST_CASE_NUMBER"

  format_human_friendly_duration "$NUMBER_OF_SECONDS"

  if [[ $ELAPSED_TIME_STR != "$EXPECTED_RESULT" ]]; then

    local ERR_MSG

    ERR_MSG+="Test case failed:"$'\n'
    ERR_MSG+="- Number of seconds: $NUMBER_OF_SECONDS"$'\n'
    ERR_MSG+="- Result           : $ELAPSED_TIME_STR"$'\n'
    ERR_MSG+="- Expected         : $EXPECTED_RESULT"

    abort "$ERR_MSG"

  fi
}


self_test_format_human_friendly_duration ()
{
  local SAVED_LC_NUMERIC="$LC_NUMERIC"
  LC_NUMERIC=""  # The thousands separators should be the default ones.

  local FHFD_TEST_CASE_NUMBER=0

  fhfd_test "0"  "0 seconds"
  fhfd_test "1"  "1 second"
  fhfd_test "59" "59 seconds"

  fhfd_test "$(( SECONDS_IN_WEEK        ))"  "1 week (604,800 seconds)"
  fhfd_test "$(( SECONDS_IN_WEEK * 2    ))"  "2 weeks (1,209,600 seconds)"
  fhfd_test "$(( SECONDS_IN_WEEK * 1234 ))"  "1,234 weeks (746,323,200 seconds)"

  fhfd_test "$(( SECONDS_IN_WEEK +     SECONDS_IN_DAY ))"  "1 week and 1 day (691,200 seconds)"
  fhfd_test "$(( SECONDS_IN_WEEK + 2 * SECONDS_IN_DAY ))"  "1 week and 2 days (777,600 seconds)"

  fhfd_test "$(( SECONDS_IN_WEEK + SECONDS_IN_DAY + SECONDS_IN_HOUR ))"  "1 week, 1 day and 1 hour (694,800 seconds)"

  fhfd_test "$(( SECONDS_IN_WEEK + SECONDS_IN_DAY + SECONDS_IN_HOUR + SECONDS_IN_MINUTE ))"  "1 week, 1 day, 1 hour and 1 minute (694,860 seconds)"

  fhfd_test "$(( SECONDS_IN_WEEK + SECONDS_IN_DAY + SECONDS_IN_HOUR + SECONDS_IN_MINUTE + 3 ))"  "1 week, 1 day, 1 hour, 1 minute and 3 seconds (694,863 seconds)"

  fhfd_test "$(( SECONDS_IN_WEEK + SECONDS_IN_HOUR ))"  "1 week and 1 hour (608,400 seconds)"

  fhfd_test "$(( SECONDS_IN_WEEK + SECONDS_IN_HOUR + 2 * SECONDS_IN_MINUTE ))"  "1 week, 1 hour and 2 minutes (608,520 seconds)"

  fhfd_test "$(( SECONDS_IN_WEEK + SECONDS_IN_HOUR + 2 * SECONDS_IN_MINUTE + 3 ))"  "1 week, 1 hour, 2 minutes and 3 seconds (608,523 seconds)"

  fhfd_test "$(( 2 * SECONDS_IN_WEEK + 1 ))"  "2 weeks and 1 second (1,209,601 seconds)"

  fhfd_test "$(( SECONDS_IN_DAY ))"  "1 day (86,400 seconds)"

  fhfd_test "$(( SECONDS_IN_MINUTE     ))"  "1 minute (60 seconds)"
  fhfd_test "$(( SECONDS_IN_MINUTE * 5 ))"  "5 minutes (300 seconds)"
  fhfd_test "$(( SECONDS_IN_MINUTE + 3 ))"  "1 minute and 3 seconds (63 seconds)"

  # There is a shortcoming here: this restore operation does not run if an error occurs above.
  LC_NUMERIC="$SAVED_LC_NUMERIC"
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2011-2023 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool runs a command with Bash, saves its stdout and stderr output and generates a report file."
  echo
  echo "Very long log files are often difficult to deal with, so storing a separate log file per task"
  echo "can be helpful on its own. You can also use companion tool GenerateBuildReport.pl to generate"
  echo "an HTML table with the succeeded (in green) and failed (in red) status of all commands run."
  echo "You can then conveniently drill-down to each command's output."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> command <command arguments...>"
  echo
  echo "Options:"
  echo " --help      displays this help text and exits"
  echo " --version   displays the tool's version number (currently $VERSION_NUMBER) and exits"
  echo " --license   prints license information and exits"
  echo " --self-test runs some internal tests and exits"
  echo " --id=xxx    Programmatic name of this task, for reporting purposes."
  echo "             This option is normally a must, as each task needs a different ID."
  echo " --userFriendlyName=xxx An optional user-friendly name for this task, for reporting purposes."
  echo " --logFilename=xxx      The default log filename is derived from the task ID."
  echo " --reportFilename=xxx   Companion tool GenerateBuildReport.pl needs these files."
  echo "                        The default report filename is derived form the task ID."
  echo "                        If you want to prevent the creation of the report file,"
  echo "                        set the filename to /dev/null ."
  echo " --hide-from-report-if-successful  Sometimes, a task is only worth reporting when it fails."
  echo " --quiet                 Suppress printing command banner, exit code and elapsed time."
  echo " --copy-stderr=filename  Copies stderr to a separate file. This is sometimes useful"
  echo "                         to tell whether there was any stderr output at all."
  echo "                         This uses a separate 'tee' process for stderr, so the order of"
  echo "                         stdout and stderr mixing in the normal log file may change a little."
  echo "                         This separate file does not appear in the report (no yet implemented)."
  echo
  echo "Usage example:"
  echo "  ./$SCRIPT_NAME --id=test1 -- echo \"Test 1 output.\""
  echo
  echo "Exit status:"
  echo "  If an error occurs inside this script, it yields a non-zero exit code."
  echo "  Otherwise, the exit status is the same as the command executed."
  echo "  Note that this script assumes that an exit status of 0 means success."
  echo
  echo "Script history:"
  echo "  Compatibility break between script versions 1.07 und 1.08:"
  echo "  The command-line options have changed, the task ID etc."
  echo "  are no longer positional arguments."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license ()
{
cat - <<EOF

Copyright (c) 2011-2023 R. Diez

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
    self-test)
        self_test_format_human_friendly_duration
        exit $EXIT_CODE_SUCCESS
        ;;
    copy-stderr)
        if [[ $OPTARG = "" ]]; then
          abort "Option --copy-stderr has an empty value."
        fi
        STDERR_COPY_FILENAME="$OPTARG"
        ;;
    id)
        if [[ $OPTARG = "" ]]; then
          abort "Option --id has an empty value."
        fi
        PROGRAMMATIC_NAME="$OPTARG"
        ;;
    userFriendlyName)
        if [[ $OPTARG = "" ]]; then
          abort "Option --userFriendlyName has an empty value."
        fi
        USER_FRIENDLY_NAME="$OPTARG"
        ;;
    logFilename)
        if [[ $OPTARG = "" ]]; then
          abort "Option --logFilename has an empty value."
        fi
        LOG_FILENAME="$OPTARG"
        ;;
    reportFilename)
        if [[ $OPTARG = "" ]]; then
          abort "Option --reportFilename has an empty value."
        fi
        REPORT_FILENAME="$OPTARG"
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
USER_LONG_OPTIONS_SPEC+=( [self-test]=0 )
USER_LONG_OPTIONS_SPEC+=( [copy-stderr]=1 )
USER_LONG_OPTIONS_SPEC+=( [id]=1 )
USER_LONG_OPTIONS_SPEC+=( [userFriendlyName]=1 )
USER_LONG_OPTIONS_SPEC+=( [logFilename]=1 )
USER_LONG_OPTIONS_SPEC+=( [reportFilename]=1 )

HIDE_FROM_REPORT_IF_SUCCESSFUL=false
QUIET=false
STDERR_COPY_FILENAME=""
PROGRAMMATIC_NAME="DefaultTaskId"
USER_FRIENDLY_NAME=""
LOG_FILENAME=""
REPORT_FILENAME=""

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} < 1 )); then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

if [ -z "$USER_FRIENDLY_NAME" ]; then
  USER_FRIENDLY_NAME="$PROGRAMMATIC_NAME"
fi

if [ -z "$LOG_FILENAME" ]; then
  LOG_FILENAME="$PROGRAMMATIC_NAME-log.txt"
fi

if [ -z "$REPORT_FILENAME" ]; then
  REPORT_FILENAME="$PROGRAMMATIC_NAME.report"
fi


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

  if [[ $PROGRAMMATIC_NAME != "$USER_FRIENDLY_NAME" ]]; then
    echo "Programmatic task name: $PROGRAMMATIC_NAME"
  fi

  printf "Command: %s" "$USER_CMD"
  echo

  echo "Current directory: $PWD"
  echo "This file's character encoding: ${LANG:-(unknown, the LANG environment variable is not set)}"
  echo "Start time:  Local: $START_TIME_LOCAL, UTC: $START_TIME_UTC"
  echo "Environment variables:"
  export
  echo
  echo "Start of log for \"$USER_FRIENDLY_NAME\""
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

format_human_friendly_duration "$ELAPSED_SECONDS"

if (( CMD_EXIT_CODE == 0 )); then
  FINISHED_MSG="The command finished successfully (exit code 0)."
else
  FINISHED_MSG="The command failed with exit code $CMD_EXIT_CODE."
fi

{
  echo
  echo "End of log for \"$USER_FRIENDLY_NAME\""
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

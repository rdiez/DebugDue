#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r SCRIPT_NAME="GeneratePicolibcCrossFile.sh"
declare -r VERSION_NUMBER="1.00"

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

This script generates a file with the cross-compilation settings needed to build Picolibc.

Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

Syntax:
  $SCRIPT_NAME  [options]

The generated file contents are sent to stdout.

Options:
 --help     displays this help text
 --version  displays this tool's version number (currently $VERSION_NUMBER)
 --license  prints license information
 --target-arch=triplet    The GCC cross-compilation triplet. Example: arm-none-eabi
 --system=name            The system name does not really matter. The default is 'unknown-system'.
 --cpu-family=name        The Meson build system documents all supported CPU family names.
                          Example CPU family name: arm
 --cpu=name               The CPU name does not really matter. The default is 'unknown-cpu'.
                          Example CPU name: cortex-m3
 --endianness=little/big  The CPU endianness. Example: 'little'.
 --cflag=xxx              Add a C compiler flag for the target. Example: --cflag="-O2"
 --meson-compat=0.55      Provides compability with Meson versions up to 0.55.

Usage example:
  ./$SCRIPT_NAME \\
    --target-arch=arm-none-eabi \\
    --cpu-family=arm            \\
    --cpu=cortex-m3             \\
    --endianness=little         \\
    --cflag="-g"                \\
    --cflag="-O2"               \\
    >cross-build-settings.txt

If you are calling this script from a GNU Make makefile, and you have a variable with all compiler flags,
you can generate the corresponding --cflags=xxx options like this:
  \$(patsubst %,--cflag=%,\$(PICOLIBC_C_FLAGS_FOR_TARGET))

Exit status: 0 means success. Any other value means error.

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2022 R. Diez

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

    target-arch)
        if [[ $OPTARG = "" ]]; then
          abort "Option --target-arch has an empty value.";
        fi
        TARGET_ARCH="$OPTARG"
        ;;

    cpu-family)
        if [[ $OPTARG = "" ]]; then
          abort "Option --cpu-family has an empty value.";
        fi
        CPU_FAMILY_NAME="$OPTARG"
        ;;

    cpu)
        if [[ $OPTARG = "" ]]; then
          abort "Option --cpu has an empty value.";
        fi
        CPU_NAME="$OPTARG"
        ;;

    system)
        if [[ $OPTARG = "" ]]; then
          abort "Option --system has an empty value.";
        fi
        SYSTEM_NAME="$OPTARG"
        ;;

    endianness)
        if [[ $OPTARG = "" ]]; then
          abort "Option --endianness has an empty value.";
        fi
        ENDIANNESS="$OPTARG"
        ;;

    cflag)
        if [[ $OPTARG = "" ]]; then
          abort "Option --cflag has an empty value.";
        fi
        CFLAGS_FOR_TARGET+=("$OPTARG")
        ;;

    meson-compat)
        if [[ $OPTARG = "" ]]; then
          abort "Option --meson-compat has an empty value.";
        fi
        MESON_COMPATIBILITY="$OPTARG"
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


escape_for_meson_string ()
{
  local    STR="$1"
  local -r RESULT_VAR_NAME="$2"

  if [[ $STR =~ [[:cntrl:]] ]]; then
    abort "The argument to escape for a meson string contains ASCII control characters."
  fi

  STR="${STR//\\/\\\\}"  # Replace \ with \\
  STR="${STR//\'/\\\'}"  # Replace ' with \'

  printf -v "$RESULT_VAR_NAME" "%s" "$STR"
}


# ----- Entry point -----

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [target-arch]=1 )
USER_LONG_OPTIONS_SPEC+=( [cpu-family]=1 )
USER_LONG_OPTIONS_SPEC+=( [cpu]=1 )
USER_LONG_OPTIONS_SPEC+=( [system]=1 )
USER_LONG_OPTIONS_SPEC+=( [endianness]=1 )
USER_LONG_OPTIONS_SPEC+=( [cflag]=1 )
USER_LONG_OPTIONS_SPEC+=( [meson-compat]=1 )

declare -a CFLAGS_FOR_TARGET=()

TARGET_ARCH=""
CPU_FAMILY_NAME=""
ENDIANNESS=""
MESON_COMPATIBILITY=""

# The system name is not really used by Meson.
SYSTEM_NAME="unknown-system"

# The CPU name is not really used by Meson, see:
#   https://github.com/mesonbuild/meson/issues/7037
CPU_NAME="unknown-cpu"

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} != 0 )); then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

if [[ $TARGET_ARCH = "" ]]; then
  abort "Option  --target-arch is required."
fi

if [[ $CPU_FAMILY_NAME = "" ]]; then
  abort "Option  --cpu-family is required."
fi

if [[ $ENDIANNESS = "" ]]; then
  abort "Option  --endianness is required."
fi


escape_for_meson_string "$TARGET_ARCH"     "ESCAPED_TARGET_ARCH"
escape_for_meson_string "$SYSTEM_NAME"     "ESCAPED_SYSTEM_NAME"
escape_for_meson_string "$CPU_FAMILY_NAME" "ESCAPED_CPU_FAMILY_NAME"
escape_for_meson_string "$CPU_NAME"        "ESCAPED_CPU_NAME"
escape_for_meson_string "$ENDIANNESS"      "ESCAPED_ENDIANNESS"


C_ARGS=""

declare -r ARG_BASE_INDENTATION="         "
declare -r ARG_EXTRA_INDENTATION="  "

for ARG in "${CFLAGS_FOR_TARGET[@]}"
do

  if [[ $C_ARGS != "" ]]; then
    C_ARGS+=","
  fi

  C_ARGS+=$'\n'"$ARG_BASE_INDENTATION$ARG_EXTRA_INDENTATION"

  escape_for_meson_string "$ARG" "ESCAPED_ARG"

  C_ARGS+="'$ESCAPED_ARG'"

done

if [[ $C_ARGS != "" ]]; then
  C_ARGS+=$'\n'"$ARG_BASE_INDENTATION"
fi

case "$MESON_COMPATIBILITY" in
  '') SECTION_HEADER_FOR_FLAGS=$'\n'"[built-in options]";;

  0.55)  # Since Meson version 0.56.0, released on 2020-10-30, you get the following warning:
         # DEPRECATION: c_args in the [properties] section of the machine file is deprecated, use the [built-in options] section.
         # See this commit: https://github.com/mesonbuild/meson/pull/6597
         SECTION_HEADER_FOR_FLAGS="";;

  *) abort "Unsupported value of --meson-compat: $MESON_COMPATIBILITY";;
esac


set +o errexit  # When 'read' reaches end of file, a non-zero status code is returned.

read -r -d '' FILE_CONTENTS <<EOF
[binaries]
c = '$ESCAPED_TARGET_ARCH-gcc'
ar = '$ESCAPED_TARGET_ARCH-ar'
as = '$ESCAPED_TARGET_ARCH-as'
nm = '$ESCAPED_TARGET_ARCH-nm'
strip = '$ESCAPED_TARGET_ARCH-strip'

[host_machine]
system = '$ESCAPED_SYSTEM_NAME'
cpu_family = '$ESCAPED_CPU_FAMILY_NAME'
cpu = '$ESCAPED_CPU_NAME'
endian = '$ESCAPED_ENDIANNESS'

[properties]
skip_sanity_check = true
$SECTION_HEADER_FOR_FLAGS
c_args = [$C_ARGS]
EOF

set -o errexit

echo "$FILE_CONTENTS"

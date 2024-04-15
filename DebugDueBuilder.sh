#!/bin/bash

# Copyright (c) 2014-2022 R. Diez - Licensed under the GNU AGPLv3 - see below for more information.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


user_config ()
{
  DEFAULT_TOOLCHAIN_DIR="$HOME/SomeDir/DebugDueToolchain"

  DEFAULT_PATH_TO_OPENOCD="$HOME/SomeDir/openocd-0.10.0-bin/bin/openocd"

  # This setting only matters when using the 'bossac' tool.
  DEFAULT_PATH_TO_BOSSAC="bossac"

  # This setting only matters when using the 'bossac' tool.
  PROGRAMMING_USB_VIRTUAL_SERIAL_PORT="/dev/serial/by-id/usb-Arduino__www.arduino.cc__Arduino_Due_Prog._Port_7523230323535180A120-if00"

  DEFAULT_DEBUG_ADAPTER="DebugDue"

  # This setting only matters for the 'DebugDue' adapter. This is the location of the
  # 'native' USB virtual serial port of the Arduino Due that is acting as a JTAG adapter.
  # OpenOCD will be told that this is where to find the (emulated) Bus Pirate.
  DEBUGDUE_SERIAL_PORT="/dev/serial/by-id/usb-Arduino_Due_JTAG_Adapter_DebugDue1-if00"

  DEFAULT_PROJECT="DebugDue"

  DEFAULT_BUILD_TYPE="debug"

  DEFAULT_DEBUGGER_TYPE="gdb"

  DEFAULT_BUILD_OUTPUT_BASE_SUBDIR="BuildOutput"
  DEFAULT_BUILD_OUTPUT_BASE_DIR="$(readlink --verbose --canonicalize -- "$DEFAULT_BUILD_OUTPUT_BASE_SUBDIR")"
}


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


str_starts_with ()
{
  # $1 = string
  # $2 = prefix

  # From the bash manual, "Compound Commands" section, "[[ expression ]]" subsection:
  #   "Any part of the pattern may be quoted to force the quoted portion to be matched as a string."
  # Also, from the "Pattern Matching" section:
  #   "The special pattern characters must be quoted if they are to be matched literally."

  if [[ $1 == "$2"* ]]; then
    return 0
  else
    return 1
  fi
}


quote_and_append_args ()
{
  local -n VAR="$1"
  shift

  local STR

  # Shell-quote all arguments before joining them into a single string.
  printf -v STR  "%q "  "$@"

  # Remove the last character, which is one space too much.
  STR="${STR::-1}"

  if [ -z "$VAR" ]; then
    VAR="$STR"
  else
    VAR+="  $STR"
  fi
}


delete_dir_if_exists ()
{
  # $1 = dir name

  if [ -d "$1" ]
  then
    echo "Deleting directory \"$1\" ..."

    rm -rf -- "$1"

    # Sometimes under Windows/Cygwin, directories are not immediately deleted,
    # which may cause problems later on.
    if [ -d "$1" ]; then abort "Cannot delete directory \"$1\"."; fi
  fi
}


create_dir_if_not_exists ()
{
  # $1 = dir name

  if ! test -d "$1"
  then
    echo "Creating directory \"$1\" ..."
    mkdir --parents -- "$1"
  fi
}


delete_file_if_exists ()
{
  # $1 = file name

  if [ -f "$1" ]
  then
    echo "Deleting file \"$1\" ..."

    rm -f -- "$1"

    # Sometimes under Windows/Cygwin, directories are not immediately deleted,
    # which may cause problems later on. I am not sure is the same is true for files.
    if [ -f "$1" ]; then abort "Cannot delete file \"$1\"."; fi
  fi
}


get_uptime ()
{
  local PROC_UPTIME_STR  # Variable declared on a separate line, or it would mask any errors on the right part of the assignment.
  PROC_UPTIME_STR="$(</proc/uptime)"

  local PROC_UPTIME_COMPONENTS
  # Split on blanks.
  IFS=$' \t' read -r -a PROC_UPTIME_COMPONENTS <<< "$PROC_UPTIME_STR"
  if [ ${#PROC_UPTIME_COMPONENTS[@]} -ne 2 ]; then
    abort "Invalid /proc/uptime format."
  fi

  CURRENT_UPTIME="${PROC_UPTIME_COMPONENTS[0]}"
}


# WARNING: 32-bit versions of Bash will not be able to cope with elapsed times greater than 248 days.

generate_elapsed_time_msg ()
{
  # Function argument $1 is the elapsed time in hundredths of seconds.
  local -i ELAPSED_TIME="$1"

  local sign

  if [ "$ELAPSED_TIME" -lt 0 ]
  then
    ELAPSED_TIME=$((-ELAPSED_TIME))
    sign="-"
  else
    sign=""
  fi

  local -i hundredths_of_seconds=$(( ELAPSED_TIME % 100 ))

  local -i total_seconds=$(( ELAPSED_TIME / 100 ));
  local -i seconds=$total_seconds
  local -i weeks=0;
  local -i days=0;
  local -i hours=0;
  local -i minutes=0;

  if [ $seconds -gt 0 ]
  then
    minutes=$(( seconds / 60 ))
    seconds=$(( seconds % 60 ))
  fi

  if [ $minutes -gt 0 ]
  then
    hours=$(( minutes / 60 ))
    minutes=$(( minutes % 60 ))
  fi

  if [ $hours -gt 0 ]
  then
    days=$(( hours / 24 ))
    hours=$(( hours % 24 ))
  fi

  if [ $days -gt 0 ]
  then
    weeks=$(( days / 7 ))
    days=$(( days % 7 ))
  fi


  local res
  printf -v res "%d.%02d s" $seconds $hundredths_of_seconds;

  if [ $(( minutes + hours + days + weeks )) -gt 0 ]
  then
    printf -v res "%d min %s" "$minutes" "$res"
  fi

  if [ $(( hours + days + weeks )) -gt 0 ]
  then
    if [ $hours -eq 1 ]; then
      local hour_str="hour"
    else
      local hour_str="hours"
    fi

    printf -v res "%d %s %s" "$hours" "$hour_str" "$res"
  fi

  if [ $(( days + weeks )) -gt 0 ]
  then
    if [ $days -eq 1 ]; then
      local day_str="day"
    else
      local day_str="days"
    fi

    printf -v res "%d %s %s" "$days" "$day_str" "$res"
  fi

  if [ $weeks -gt 0 ]
  then
    if [ $weeks -eq 1 ]; then
      local week_str="week"
    else
      local week_str="weeks"
    fi

    printf -v res "%d %s %s" "$weeks" "$week_str" "$res"
  fi

  ELAPSED_TIME_MSG="$sign$res"

  # Every now and then, the user may want to compare elapsed times.
  # For example, the last change may make the build 10% faster.
  # It is hard to compare elapsed times if they have minutes, hours and so on.
  # Therefore, append to the message the total number of seconds.
  if [ $total_seconds -ge 60 ]
  then
    local tmp
    printf -v tmp "%d.%02d s" $total_seconds $hundredths_of_seconds
    ELAPSED_TIME_MSG+=" ($tmp)"
  fi
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME - Copyright (c) 2014-2022 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script builds/runs/etc. the DebugDue project. You would normally run
the script from your development environment (Emacs, Vim, Eclipse, ...).

Syntax:
  $SCRIPT_NAME <switches...>

Information switches:
 --help     Displays this help text.
 --license  Prints license information.

All steps below are optional. The step number gives the order in which
the steps are run if requested.

Step 1, clean operation and configuration options:
  --clean  Deletes the -obj and -bin directories for the given build type
           and the 'configure' script, if they exist, so that the
           next build will start from scratch.
  --enable-configure-cache  Enables the cache file when invoking
           autoconf's 'configure' script. This will save some time
           when rebuilding from scratch.
           You should not use a cache file if you are changing configure.ac
           or some other autoconf source file in this project. You should also
           drop the cache after changing your system's configuration,
           such as after installing a new software package.
           The local cache file (if any) will be dropped if you run this script
           without enabling the cache.
  --configure-cache-filename="filename"
           This option triggers --enable-configure-cache, but, instead
           of using a local cache file, the given one will be used.
           The caller is then responsible for the lifetime of the supplied
           cache file, as this script will never drop it.
  --enable-ccache   Uses 'ccache', which can possibly reduce compilation times.
                    You can only enable ccache when configuring the project
                    for the first time (or after cleaning it).
                    There are also some caveats, see this script's source code
                    for details about ccache.

Step 2, build operations:
  --build    Runs "make" for the default target. Generates the autoconf
             files beforehand if necessary.
  --install  Runs "make install". Normally not needed.
  --atmel-software-framework="<path>"  Directory where the ASF is installed.
                                       Only needed if the project requires it.
  --show-build-commands  Show the full compilation commands during the build.
  --disassemble  Generate extra information files from the just-built ELF file:
                 complete disassembly, list of objects sorted by size,
                 sorted list of strings (with 'strings' command), readelf dump.
  --make-arg=ARG  Pass an extra argument to 'make'. This is primarily intended
                  for make variables. For example: --make-arg CPPFLAGS=-Dmysymbol=1
                  You can specify --make-arg several times.
  --build-output-base-dir="<path>"  Where the build output will land.
                                    Defaults to '$DEFAULT_BUILD_OUTPUT_BASE_SUBDIR'.

  The default is not to build anything. If you then debug your firmware,
  make sure that the existing binary matches the code on the target.
  That is, do not forget to program it first on the target.

Step 3, program operations:
  --program-over-jtag  Transfers the firmware over JTAG to the target device.
  --program-with-bossac  Transfers the firmware with 'bossac' to the target device.
  --verify  After programming, verify that the firmware was written correctly.
  --cache-programmed-file  Programming a new binary takes time. If the binary has not
                           changed, this option skips programming.
                           Warning: This assumes exclusive access to a single device.
                           If some other tool reprograms the Arduino Due, or it
                           is swapped out for a different Arduino Due, it will confuse
                           the build script. In this case, either re-run without
                           this option or delete the cached binary file to force
                           reprogramming.
  --path-to-bossac="path/to/bossac"  The default is "bossac", which only works
                                     if is is on the PATH. Under Ubuntu/Debian,
                                     the package to install is called 'bossa-cli'.
  --debug-adapter=xxx  What debug adapter to use:
                       DebugDue, Flyswatter2 or Olimex-ARM-USB-OCD-H.

Step 4, debug operations:
  --debug  Starts the firmware under the debugger (GDB connected to
           OpenOCD over JTAG).
  --debugger-type="<type>"  Debugger types are "gdb" and "ddd" (a graphical
                            interface to GDB).
  --debug-from-the-start  Breaks as soon as possible after starting the firmware.
  --add-breakpoint="function name or line position like Main.cpp:123"
  --openocd-path="openocd-0.10.0/bin/openocd"  Path to the OpenOCD executable.

Global options:
  --project="<project name>"  Specify 'DebugDue' (the default), 'EmptyFirmware' or 'QemuFirmware'.
  --toolchain-dir="<path>"
  --build-type="<type>"  Build types are "debug" and "release".

Examples:
  First of all, you may want to edit routine user_config() in this script
  in order to set the default options according to your system.
  This way, you do not have to specify any global configuration switches
  on each run.

  Every time you make a change in the source code, you would normally run:
    $SCRIPT_NAME --build --build-type="debug"

  At some point in time, you want to debug your firmware with:
    $SCRIPT_NAME --build --build-type="debug" --program-over-jtag --debug

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-arduino at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2014-2022 R. Diez

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


check_only_one ()
{
  local ERR_MSG="$1"

  shift

  local -i COUNT=0

  for arg do

    if $arg; then
      COUNT=$((COUNT+1))
    fi
  done

  if [ $COUNT -gt 1 ]; then
    abort "$ERR_MSG"
  fi
}


do_clean ()
{
  echo "Cleaning the project's output directories..."
  delete_dir_if_exists "$PROJECT_OBJ_DIR"
  delete_dir_if_exists "$PROJECT_BIN_DIR"
  delete_file_if_exists "$CONFIGURE_SCRIPT_PATH"
}


do_autogen_if_necessary ()
{
  if ! [ -f "$CONFIGURE_SCRIPT_PATH" ]; then
    echo "File \"$CONFIGURE_SCRIPT_PATH\" does not exist, running the autotools..."

    pushd "$PROJECT_SRC_DIR" >/dev/null
    ./autogen.sh
    popd >/dev/null

    if ! [ -f "$CONFIGURE_SCRIPT_PATH" ]; then
      abort "File \"$CONFIGURE_SCRIPT_PATH\" is not where it is expected to be."
    fi

    echo "Finished running the autotools."
  fi
}


do_configure_if_necessary ()
{
  local MAKEFILE_PATH="$PROJECT_OBJ_DIR/Makefile"

  if ! [ -f "$MAKEFILE_PATH" ]; then
    echo "File \"$MAKEFILE_PATH\" does not exist, running the configure step..."

    pushd "$PROJECT_OBJ_DIR" >/dev/null

    local CONFIG_CMD=""

    quote_and_append_args CONFIG_CMD "CONFIG_SHELL=/bin/bash"
    quote_and_append_args CONFIG_CMD "$CONFIGURE_SCRIPT_PATH"

    if $ENABLE_CONFIGURE_CACHE_SPECIFIED; then
      echo "Using configure cache file \"$CONFIGURE_CACHE_FILENAME\"."
      quote_and_append_args CONFIG_CMD "--cache-file=$CONFIGURE_CACHE_FILENAME"
    else
      # If the cache file to use comes as a command-line argument, then the user
      # is responsible for the cache file's lifetime.
      # This script will only delete its local, default cache file
      # if it has not been told to use it.
      delete_file_if_exists "$DEFAULT_CONFIGURE_CACHE_FILENAME"
    fi

    quote_and_append_args CONFIG_CMD "--prefix=$PROJECT_BIN_DIR"

    if [[ $BUILD_TYPE = debug ]]; then
      quote_and_append_args CONFIG_CMD "--enable-debug=yes"
      # echo "Creating a debug build..."
    else
      quote_and_append_args CONFIG_CMD "--enable-debug=no"
      # echo "Creating a release build..."
    fi

    if [ -n "$ASF_DIR" ]; then
      quote_and_append_args CONFIG_CMD "--with-atmel-software-framework=$ASF_DIR"
    fi

    quote_and_append_args CONFIG_CMD "--with-project=$PROJECT_NAME"

    quote_and_append_args CONFIG_CMD "--host=$TARGET_ARCH"
    # I have not figured out yet how to get the value passed as --host to configure.ac ,
    # so I am passing it again in a separate command-line option.
    quote_and_append_args CONFIG_CMD "--with-target-arch=$TARGET_ARCH"

    # Use GCC's wrappers for 'ar' and 'ranlib'. Otherwise, when using the binutils versions directly,
    # they will complain about a missing plug-in to process object files compiled for LTO.
    # I reported this issue to the Autoconf project:
    #   sr #110475: ranlib: plugin needed to handle lto object
    #   https://savannah.gnu.org/support/index.php?110475
    quote_and_append_args CONFIG_CMD "AR=$TARGET_ARCH-gcc-ar"
    quote_and_append_args CONFIG_CMD "RANLIB=$TARGET_ARCH-gcc-ranlib"

    if $ENABLE_CCACHE_SPECIFIED; then

      # You probably do not want to turn ccache on unconditionally. The price of a cache miss
      # in a normal compilation can be as high as 20 %. There are many more disk writes during
      # compilation, so pressure increases on the system's disk cache.
      #
      # Therefore, ccache only helps if you recompile often with the same results.
      # For example, if you rebuild many times from scratch during testing of
      # your application's build script. And you are always using the same compiler.
      #
      # It also helps if your changes end up generating the same preprocessor output
      # for many of the recompiled files. For example, if you amend just comments,
      # or you change something under #ifdef DEBUG in a header file included by many
      # source files, but you are compiling a release build at the moment.
      #
      # Using ccache also means more admin work. You should check every now and then
      # whether your cache hits are high enough. Otherwise, you may have to increase
      # your global cache size, or you will actually be losing performance.
      #
      # Beware that ccache is not completely reliable: adding a new header file
      # may change the compilation results, and ccache may not realise.
      # This corner case is documented in ccache's user manual.

      CCACHE_NAME="ccache"
      if type "$CCACHE_NAME" >/dev/null 2>&1 ; then
        quote_and_append_args CONFIG_CMD "CC=$CCACHE_NAME $TARGET_ARCH-gcc"
        quote_and_append_args CONFIG_CMD "CXX=$CCACHE_NAME $TARGET_ARCH-g++"
      else
        abort "Tool '$CCACHE_NAME' not found."
      fi
    fi

    echo "$CONFIG_CMD"
    eval "$CONFIG_CMD"

    if ! [ -f "$MAKEFILE_PATH" ]; then
      abort "File \"$MAKEFILE_PATH\" is not where it is expected to be."
    fi

    popd >/dev/null

    echo "Finished running the configure step."
  fi
}


check_whether_compiler_is_present ()
{
  local COMPILER_NAME="$TARGET_ARCH-gcc"

  # If you don't get the PATH right, the ./configure script will not find the right compiler,
  # and the error message you'll get much further down is not immediately obvious.
  # Therefore, check beforehand that we do find the right compiler.
  if ! type "$COMPILER_NAME" >/dev/null 2>&1 ;
  then
    abort "Could not find compiler \"$COMPILER_NAME\", did you get the toolchain path right? I am using: $TOOLCHAIN_DIR"
  fi

  if false; then
    echo "Compiler \"$COMPILER_NAME\" exists. The version is:"
    "$COMPILER_NAME" -v
  fi
}


process_command_line_argument ()
{
  case "$OPTION_NAME" in
    help)
        display_help
        exit $EXIT_CODE_SUCCESS
        ;;
    license)
        display_license
        exit $EXIT_CODE_SUCCESS
        ;;

    clean) CLEAN_SPECIFIED=true;;

    verify) VERIFY_SPECIFIED=true;;

    enable-configure-cache) ENABLE_CONFIGURE_CACHE_SPECIFIED=true;;

    configure-cache-filename)
      ENABLE_CONFIGURE_CACHE_SPECIFIED=true
      if [[ $OPTARG = "" ]]; then
        abort "Option --configure-cache-filename has an empty value."
      fi
      CONFIGURE_CACHE_FILENAME="$OPTARG"
      ;;

    build) BUILD_SPECIFIED=true;;
    enable-ccache) ENABLE_CCACHE_SPECIFIED=true;;
    install) INSTALL_SPECIFIED=true;;
    disassemble) DISASSEMBLE_SPECIFIED=true;;
    program-over-jtag) PROGRAM_OVER_JTAG_SPECIFIED=true;;
    program-with-bossac) PROGRAM_WITH_BOSSAC_SPECIFIED=true;;
    cache-programmed-file) CACHE_PROGRAMMED_FILE_SPECIFIED=true;;
    debug) DEBUG_SPECIFIED=true;;
    debug-from-the-start) DEBUG_FROM_THE_START_SPECIFIED=true;;
    show-build-commands) SHOW_BUILD_COMMANDS=true;;

    path-to-bossac)
        if [[ $OPTARG = "" ]]; then
          abort "The --path-to-bossac option has an empty value."
        fi
        PATH_TO_BOSSAC="$OPTARG"
        ;;

    toolchain-dir)
        if [[ $OPTARG = "" ]]; then
          abort "The --toolchain-dir option has an empty value."
        fi
        TOOLCHAIN_DIR="$OPTARG"
        ;;

    build-output-base-dir)
        if [[ $OPTARG = "" ]]; then
          abort "The --build-output-base-dir option has an empty value."
        fi
        BUILD_OUTPUT_BASE_DIR="$OPTARG"
        ;;

    atmel-software-framework)
        if [[ $OPTARG = "" ]]; then
          abort "The --atmel-software-framework option has an empty value."
        fi
        ASF_DIR="$OPTARG"
        ;;

    build-type)
        if [[ $OPTARG = "" ]]; then
          abort "The --build-type option has an empty value."
        fi
        BUILD_TYPE="$OPTARG"
        ;;

    debugger-type)
        if [[ $OPTARG = "" ]]; then
          abort "The --debugger-type option has an empty value."
        fi
        DEBUGGER_TYPE="$OPTARG"
        ;;

    add-breakpoint)
        if [[ $OPTARG = "" ]]; then
          abort "The --add-breakpoint option has an empty value."
        fi
        BREAKPOINTS+=("$OPTARG")
        ;;

    openocd-path)
        if [[ $OPTARG = "" ]]; then
          abort "The --openocd-path option has an empty value."
        fi
        PATH_TO_OPENOCD="$OPTARG"
        ;;

    debug-adapter)
      if [[ $OPTARG = "" ]]; then
        abort "Option --debug-adapter has an empty value."
      fi
      DEBUG_ADAPTER="$OPTARG"
      ;;

    project)
        PROJECT="$OPTARG"
        ;;

    make-arg)
        if [[ $OPTARG = "" ]]; then
          abort "The --make-arg option has an empty value."
        fi
        EXTRA_MAKE_ARGS+=("$OPTARG")
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


add_make_parallel_jobs_flag ()
{
  local SHOULD_ADD_PARALLEL_FLAG=true

  if is_var_set "MAKEFLAGS"
  then

    if false; then
      echo "MAKEFLAGS: $MAKEFLAGS"
    fi

    # The following string search is not 100 % watertight, as MAKEFLAGS can have further arguments at the end like " -- VAR1=VALUE1 VAR2=VALUE2 ...".
    if [[ $MAKEFLAGS =~ --jobserver-fds= || $MAKEFLAGS =~ --jobserver-auth= ]]
    then
      # echo "Called from a makefile with parallel jobs enabled."
      SHOULD_ADD_PARALLEL_FLAG=false
    fi
  fi

  if $SHOULD_ADD_PARALLEL_FLAG; then

    local MAKE_J_VAL
    MAKE_J_VAL="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"
    quote_and_append_args MAKE_CMD "-j" "$MAKE_J_VAL"

    # Option "--output-sync" requires GNU Make version 4.0 (released in 2013) or newer. If you have an older GNU Make, comment the following line out.
    #
    # Note that you should be using GNU Make 4.3 or later, because older GNU Make versions have issues with parallel builds:
    #   A change to how pipe waiting works promises to speed up parallel kernel builds - always a kernel developer's favorite
    #   workload - but can also trigger a bug with old versions of GNU Make.
    #   https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=0ddad21d3e99
    #
    # I have noticed that this option seems to be ignored by the GNU Make version 4.2.1 that comes with Ubuntu 20.04.2.
    # I tested on the same system with a self-compiled GNU Make 4.3, and "--output-sync" worked fine.
    #
    # Unfortunately, option "--output-sync" leads to long periods of time with no output, followed by large bursts of output.
    # It is annoying, but it is actually the only sane way of generating a build log when building in parallel.
    # And you want to build in parallel on today's multicore computers.
    #
    # Do not add this option if you will not be building in parallel, because the user may want to see any progress messages
    # straight away. An example is running a makefile to download some files: you will probably not want to enable (or
    # you may want to disable) downloading in parallel, in order to prevent overloading the network, but then you will want
    # to see without delay the download progress messages that tools like 'curl' can output.
    quote_and_append_args MAKE_CMD "--output-sync=recurse"

  fi
}


do_build ()
{
  pushd "$PROJECT_OBJ_DIR" >/dev/null

  local MAKE_CMD=""

  quote_and_append_args MAKE_CMD "make"

  if false; then
    # Possible flags:
    #   a for all
    #   b for basic debugging
    #   v for more verbose basic debugging
    #   i for showing implicit rules
    #   j for details on invocation of commands
    #   m for debugging while remaking makefiles.
    local DEBUG_FLAGS="a"
    quote_and_append_args MAKE_CMD "--debug=$DEBUG_FLAGS"
  fi

  # Normally, the build commands are not shown, see AM_SILENT_RULES in configure.ac .
  # Passing "V=1" in CPPFLAGS is not enough, you need to remove "-s" too.
  if $SHOW_BUILD_COMMANDS; then
    quote_and_append_args MAKE_CMD "V=1"
  else
    quote_and_append_args MAKE_CMD "-s"
  fi


  EXTRA_CPPFLAGS=""

  # If you are building from within emacs, GCC will not automatically turn the diagnostics colours on
  # because it is not running on a real console. You can overcome this by enabling colours in emacs'
  # build output window and then setting the following variable to 'true'.
  # You do not actually need to enable this flag, you can just set CPPFLAGS before running this script.
  local FORCE_GCC_DIAGNOSTICS_COLOR=false
  if $FORCE_GCC_DIAGNOSTICS_COLOR; then
    EXTRA_CPPFLAGS+="-fdiagnostics-color=always "
  fi


  # Show the path of all files #include'd during compilation. It often helps when debugging preprocessor problems.
  # You do not actually need to enable this flag, you can just set CPPFLAGS before running this script.
  local SHOW_INCLUDED_FILES=false
  if $SHOW_INCLUDED_FILES; then
    EXTRA_CPPFLAGS+="-H "
  fi


  # Generate the assembly files from the source files.
  # Due to the command-line arguments passed to GCC, .s output files end up actually with
  # file extension .o, like object files are named.
  # Unfortunately, this option does not generate the real object files, so the build does not complete.
  # Use -save-temps instead, see file configure.ac .
  # I have verified that option -fverbose-asm does generate extra comments in
  # the assembly files (which actually have file extension .o, see above).
  local GENERATE_ASSEMBLY_FILES=false
  if $GENERATE_ASSEMBLY_FILES; then
    EXTRA_CPPFLAGS+="-S -fverbose-asm "
  fi


  if [[ $EXTRA_CPPFLAGS != "" ]]; then
    # The user's CPPFLAGS comes at the end, so that the user always has the last word.
    quote_and_append_args MAKE_CMD "CPPFLAGS=$EXTRA_CPPFLAGS${CPPFLAGS:-}"
  fi

  quote_and_append_args MAKE_CMD "--no-builtin-rules"

  add_make_parallel_jobs_flag

  local EXTRA_ARG
  for EXTRA_ARG in "${EXTRA_MAKE_ARGS[@]}"; do
    quote_and_append_args MAKE_CMD "$EXTRA_ARG"
  done

  # After all 'make' options, append the targets.

  if $INSTALL_SPECIFIED; then
    quote_and_append_args MAKE_CMD "install"
  fi

  if $DISASSEMBLE_SPECIFIED; then
    quote_and_append_args MAKE_CMD "disassemble"
  fi

  echo "$MAKE_CMD"
  eval "$MAKE_CMD"

  local PROG_SIZE
  PROG_SIZE="$(stat -c%s "$BIN_FILEPATH")"

  printf "Resulting binary: \"$BIN_FILEPATH\", size: %'d bytes.\\n" "$PROG_SIZE"

  popd >/dev/null
}


add_openocd_cmd ()
{
  # We could write this routine like quote_and_append_args, but keep in mind that Bash and Tcl escaping
  # is different. For example, the '[' character in command "set fifo [open filename a]"
  # must not be escaped in Tcl.

  # When running .tcl files, OpenOCD does not print the function results,
  # but when running commands with --command, it does.
  # The following makes every line return an empty list, which then prints nothing,
  # effectively suppressing printing the function result.
  # I have not found a better way yet to achieve this.

  local -r SUPPRESS_PRINTING_RESULT=true

  local QUOTED

  if $SUPPRESS_PRINTING_RESULT; then
    local -r TCL_SUPPRESS_PRINTING_RESULT_SUFFIX="; list"
    quote_and_append_args OPEN_OCD_CMD "--command" "$1 $TCL_SUPPRESS_PRINTING_RESULT_SUFFIX"
  else
    quote_and_append_args OPEN_OCD_CMD "--command" "$1"
  fi
}


add_openocd_cmd_echo ()
{
  local QUOTED
  printf -v QUOTED "%q" "$1"

  add_openocd_cmd "echo $QUOTED"
}


do_bossac ()
{
  # Tool 'bossac' does not seem to give an intuitive error message if the port
  # is not there at all (at least for versions up to 1.3a). The error message
  # is the same whether the port is not present, or whether it is,
  # but the SAM-BA bootloader is not running there.
  # Therefore, manually check beforehand that the port is actually there,
  # in order to generate a more helpful error message if it is not.
  if [ ! -e "$PROGRAMMING_USB_VIRTUAL_SERIAL_PORT" ]; then
    abort "The Arduino Due's 'programming' USB virtual port is not at location \"$PROGRAMMING_USB_VIRTUAL_SERIAL_PORT\""
  fi

  if ! type "$PATH_TO_BOSSAC" >/dev/null 2>&1 ;
  then
    abort "Could not find tool \"$PATH_TO_BOSSAC\"."
  fi

  local PREFIX="/dev/"
  local -i PREFIX_LEN="${#PREFIX}"

  if ! str_starts_with "$PROGRAMMING_USB_VIRTUAL_SERIAL_PORT" "$PREFIX"; then
    abort "Tool 'bossac' expects the port location to start with \"$PREFIX\", but it does not. The port location is: \"$PROGRAMMING_USB_VIRTUAL_SERIAL_PORT\"."
  fi

  if $SAME_FILE_THEREFORE_SKIP_PROGRAMMING; then
    echo "Skipping programming, as it is the same binary file as the last time around. In order to force programming, delete the cached file:"
    echo "  $CACHED_PROGRAMMED_FILE_FILENAME"
    return
  fi

  # Delete the cached file in case programming fails, and you end up with a corrupt firmware on the target.
  if $CACHE_FILE_EXISTS_BUT_DIFFERENT; then
    rm "$CACHED_PROGRAMMED_FILE_FILENAME"
  fi

  local PORT_WITHOUT_PREFIX="${PROGRAMMING_USB_VIRTUAL_SERIAL_PORT:$PREFIX_LEN}"

  local SERIAL_PORT_CONFIG_CMD=""

  # Trigger an erase first. Otherwise, the SAM-BA bootloader will probably not be present
  # on the 'programming' USB virtual serial port and tool 'bossac' will fail.
  quote_and_append_args SERIAL_PORT_CONFIG_CMD "stty" "-F" "$PROGRAMMING_USB_VIRTUAL_SERIAL_PORT" "1200"
  echo "$SERIAL_PORT_CONFIG_CMD"
  eval "$SERIAL_PORT_CONFIG_CMD"

  local CMD=""
  quote_and_append_args CMD "$PATH_TO_BOSSAC" "--port=$PORT_WITHOUT_PREFIX"
  # bossac's option "--force_usb_port" means "Enable  automatic detection of the target's USB port"
  # and is turned on by default. We are specifying the exact path to the port,
  # so we do not want any guessing.
  quote_and_append_args CMD "--force_usb_port=false"

  # If you suspect your target is not getting flashed correctly, you can
  # turn verification on. It is normally disabled because it takes a long time.
  if $VERIFY_SPECIFIED; then
    quote_and_append_args CMD "--verify"
  fi

  quote_and_append_args CMD "--write" "$BIN_FILEPATH"
  quote_and_append_args CMD "--boot=1"

  # You could make the reset step optional, so that the new firmware does not start immediately.
  if true; then
   quote_and_append_args CMD "--reset"
  fi

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local EXIT_CODE="$?"
  set -o errexit

  if [ $EXIT_CODE -ne 0 ]; then
    local MSG
    MSG+="Tool 'bossac' failed with exit code $EXIT_CODE. Troubleshooting hints are:"
    MSG+=$'\n'
    MSG+="1) Is the Arduino Due's 'programming' USB virtual serial port really at the following location?"
    MSG+=$'\n'
    MSG+="$PROGRAMMING_USB_VIRTUAL_SERIAL_PORT"
    MSG+=$'\n'
    MSG+="2) Has some other application that port open at the same time? (It is possible under Linux)"
    MSG+=$'\n'
    MSG+="3) Is the Arduino Due's 'native' USB virtual serial port connected too? If so, disconnect it and try again."
    printf "%s" "$MSG" >&2
    exit $EXIT_CODE
  fi

  if $CACHE_PROGRAMMED_FILE_SPECIFIED; then
    echo "Keeping a copy of pogrammed file \"$BIN_FILEPATH\" at \"$CACHED_PROGRAMMED_FILE_FILENAME\" ..."
    cp -- "$BIN_FILEPATH" "$CACHED_PROGRAMMED_FILE_FILENAME"
   fi
}


check_background_job_still_running ()
{
  # Unfortunately, Bash does not provide a timeout option for the 'wait' command, or any other
  # option for it that only checks the job status without blocking.
  #
  # In order to check whether a child process is still alive, we could use something like this:
  #
  #   kill -0 "$CHILD_PID"
  #
  # However, that is unreliable, because the system can reuse PIDs at any point in time.
  # Using a Bash job spec like this does not help either:
  #
  #   kill -0 %123
  #
  # The trouble is, the internal job table is apparently not updated in non-interactive shells
  # until you execute a 'jobs' command. If the job has finished, attempting to reference
  # its job spec will succeed only once the next time around. The job spec will then be dropped,
  # and any subsequence reference to it will fail, in the best case, or will reference
  # some other later job in the worst scenario.
  #
  # Furthermore, parsing the output from 'jobs' is not easy either. Here are some examples:
  #
  #  [1]+  Done                    my command
  #  [2]-  Done(1)                 my command
  #  [3]   Terminated              my command
  #  [4]   Running                 my command
  #  [5]   Stopped                 my command
  #  [6]   Killed                  my command
  #  [7]   Terminated              my command
  #  [8]   User defined signal 1   my command
  #  [9]   Profiling timer expired my command
  #
  # '+' means it is the "current" job. '-' means it is the "previous" job.
  # 'Done' means an exit code of 0. 'Done(1)' means the process terminated with an exit status of 1.
  # 'Terminated' means SIGTERM, 'Killed' means SIGKILL, 'User defined signal 1' means SIGUSR1,
  # and 'Profiling timer expired' menas SIGPROF.
  #
  # All of the above is from empirical testing. As far as I can see, it is not documented.
  # Therefore, I assume that it can change in any future version. Those messages could
  # for example be translated in non-English locales.
  #
  # Therefore, attempting to parse the ouput is not a good idea.
  #
  # The workaround I have implemented is as follows: if 'jobs %n' fails, the job is not running
  # anymore, and the reason why not was reported in the last successful invocation of 'jobs %n'.
  # The downside is that the caller will realise that the job has finished on the next call
  # to this routine. That is, there is a delay of one routine call.

  local JOB_SPEC="$1"

  local JOBS_OUTPUT_FILENAME="$PROJECT_OBJ_DIR_TMP/JobsCmdOutput.txt"

  set +o errexit

  # We cannot capture the output as usual like this:
  #   $(jobs $JOBS_SPEC)
  # The reason is that $() runs the command in a subshell, and changes to the internal job table
  # are apparently not propagated to the parent shell instance.
  # The workaround is to use a temporary file.
  jobs "$JOB_SPEC" >"$JOBS_OUTPUT_FILENAME"

  local JOBS_EXIT_CODE="$?"

  set -o errexit

  local JOBS_OUTPUT
  JOBS_OUTPUT="$(<"$JOBS_OUTPUT_FILENAME")"

  if (( JOBS_EXIT_CODE != 0 )); then
    # Let the user see what 'jobs' printed, if anything. It will come after stderr,
    # but it is better than nothing.
    printf "%s" "$JOBS_OUTPUT"

    MSG="The background child process failed to initialise or is no longer running."
    if [ -n "$LAST_JOB_STATUS" ]; then
      MSG+=" Its job result was: "
      MSG+="$LAST_JOB_STATUS"
    fi

    abort "$MSG"
  fi

  LAST_JOB_STATUS="$JOBS_OUTPUT"
}


parse_job_id ()
{
  local JOBS_OUTPUT="$1"

  local REGEXP="^\\[([0-9]+)\\]"

  if ! [[ $JOBS_OUTPUT =~ $REGEXP ]]; then
    local ERR_MSG
    printf -v ERR_MSG "Cannot parse this output from 'jobs' command:\\n%s" "$JOBS_OUTPUT"
    abort "$ERR_MSG"
  fi

  CAPTURED_JOB_SPEC="%${BASH_REMATCH[1]}"

  if false; then
    echo "CAPTURED_JOB_SPEC: $CAPTURED_JOB_SPEC"
  fi
}


build_gdb_command ()
{
  local TARGET_TYPE="$1"

  printf  -v GDB_CMD  "cd %q  &&  ./DebuggerStarterHelper.sh"  "$OPENOCD_CONFIG_DIR"

  if $DEBUG_FROM_THE_START_SPECIFIED; then
    quote_and_append_args GDB_CMD "--debug-from-the-start"
  fi

  if (( ${#BREAKPOINTS[*]} > 0 )); then
    local BP
    for BP in "${BREAKPOINTS[@]}"; do
      quote_and_append_args GDB_CMD "--add-breakpoint" "$BP"
    done
  fi

  quote_and_append_args GDB_CMD  "$TOOLCHAIN_DIR"  "$ELF_FILEPATH"  "$TARGET_TYPE"  "$DEBUGGER_TYPE"
}


declare -r FIFO_MSG_FINISHED_INIT="FIFO message: OpenOCD finished initialising."

debug_target ()
{
  # What we want to do is actually pretty straightforward:
  #
  # 1) Start OpenOCD.
  # 2) Wait until OpenOCD is ready to accept a GDB connection.
  # 3) Start GDB in a new window.
  # 4) Wait until the user closes GDB.
  # 5) Shutdown OpenOCD.
  #
  # There are all kinds of shortcomings that make this task difficult:
  # a) OpenOCD provides no way to signal when it has initialised the GDB server.
  #    It turns out that GDB retries the TCP connection by default, see GDB commands
  #    "show tcp auto-retry" and "show tcp connect-timeout", so we do not really
  #    have to wait until OpenOCD is ready.
  #    However, synchronising both processes is still desirable for the following reasons:
  #    1) If both processes are synchronised, the first GDB connection attempt will succeed.
  #       Otherwise, any GDB connection retries will waste time: up to 200 ms during
  #       the first second, and up to 1 second afterwards, see POLL_INTERVAL in GDB's source code.
  #    2) If OpenOCD fails to start for whatever reason, it is best to report it and stop,
  #       rather than starting a second concurrent process which will timeout after a while,
  #       or has to be killed when the parent realises that OpenOCD has terminated early.
  # b) OpenOCD cannot shut itself down cleanly when GDB detaches.
  #    There is an event on detach, but shutdown down inside it will break
  #    the closing handshake with GDB and make it error.
  # c) It is very hard to coordinate child processes correctly with Bash.
  #
  # I have posted questions in the OpenOCD and Bash mailing lists to no avail:
  #
  # - https://sourceforge.net/p/openocd/mailman/message/36388664/
  # - https://lists.gnu.org/archive/html/help-bash/2018-08/msg00005.html
  #
  # In the end, I managed to implement a reasonable solution in this script by resorting
  # to a number of workarounds in this routine and its callees.


  # Build the GDB command upfront. If something is wrong, it is not worth starting OpenOCD.
  local GDB_CMD
  build_gdb_command "ArduinoDue"


  # It would be best to create an unnamed pipe between this script and the OpenOCD child process,
  # but there is no easy way to do that in Bash. There is a workaround, but it is not portable.
  # In order to overcome this hurdle, I am using a named FIFO.
  # The drawback is that, if this script dies, it will leave the named FIFO behind.
  # But there is only one such FIFO per project output directory, so that is probably OK.

  local PROJECT_OBJ_DIR_TMP="$PROJECT_OBJ_DIR/tmp"

  mkdir --parents -- "$PROJECT_OBJ_DIR_TMP"

  local FIFO_FILENAME="$PROJECT_OBJ_DIR_TMP/HasOpenOcdInitialised.fifo"

  # Delete and recreate the FIFO each time. If some other process is using the same FIFO,
  # this increases the chances that the user will notice what the problem is.

  if [ -p "$FIFO_FILENAME" ]; then
    echo "Deleting existing FIFO \"$FIFO_FILENAME\"."
    rm -- "$FIFO_FILENAME"
  fi

  echo "Creating FIFO \"$FIFO_FILENAME\"."
  mkfifo --mode=600 -- "$FIFO_FILENAME"


  if false; then
    add_openocd_cmd "error \"Simulated error 1 in OpenOCD command.\""
  fi


  # Make sure you write to the FIFO after calling OpenOCD's 'init' command.
  add_openocd_cmd_echo "Informing the parent script that OpenOCD has finished initialising."
  local FILE_OPEN_CMD
  printf -v FILE_OPEN_CMD "set fifo [open %q a]" "$FIFO_FILENAME"
  add_openocd_cmd "$FILE_OPEN_CMD"

  local PUTS_FIFO_CMD
  printf -v PUTS_FIFO_CMD "puts \$fifo %q"  "$FIFO_MSG_FINISHED_INIT"
  add_openocd_cmd "$PUTS_FIFO_CMD"
  add_openocd_cmd "close \$fifo"

  echo
  echo "Starting OpenOCD with command:"
  echo "$OPEN_OCD_CMD"
  echo
  eval "$OPEN_OCD_CMD" &

  # This first check will probably always succeed. If the child process has terminated,
  # we will find out the next time around. We are doing an initial check
  # in order to extract the exact job ID. Bash provides no other way to
  # get the job spec, as far as I can tell. Using the "last job" spec %%
  # is risky, because something else may start another job in the meantime.
  local LAST_JOB_STATUS=""
  check_background_job_still_running %%
  parse_job_id "$LAST_JOB_STATUS"
  local OPEN_OCD_JOB_SPEC="$CAPTURED_JOB_SPEC"


  # Wail until the OpenOCD child process has indicated that it has finished initialisation.
  # During the wait, check too whether the OpenOCD child process has terminated unexpectedly.
  #
  # If the timeout is too short, it will waste CPU cycles. If it is too long,
  # it will unnecessarily delay detection of a terminated OpenOCD.
  # Due to the way in which check_openocd_job_still_running is implemented,
  # the maximum detection delay is 2 x FIFO_TIMEOUT.
  # This delay is not too bad, because there will be no delay in the typical sunny day scenario.
  local -r FIFO_TIMEOUT="0.2"
  local FIFO_LINE
  local READ_EXIT_CODE

  while true; do

    set +o errexit

    # We have to open the pipe in read/write mode, therefore the "<>" below. Opening it in read-only mode will hang
    # until somebody writes to the pipe, and the timeout will not work. If the child process dies
    # before writing anything to the FIFO, we will then forever hang.
    read -t "$FIFO_TIMEOUT" -r FIFO_LINE <>"$FIFO_FILENAME"

    READ_EXIT_CODE="$?"

    set -o errexit

    if (( READ_EXIT_CODE == 0 )); then

      if [[ "$FIFO_LINE" = "$FIFO_MSG_FINISHED_INIT" ]]; then
        break
      fi

      abort "Unexpected FIFO message from OpenOCD process: $FIFO_LINE"

    fi

    # A read timeout yields an exit status > 128.

    if (( READ_EXIT_CODE <= 128 )); then
      abort "Command 'read' failed with an exit code of $READ_EXIT_CODE."
    fi


    # echo "Checking whether the child is still running."
    check_background_job_still_running  "$OPEN_OCD_JOB_SPEC"

  done


  if false; then
    # Replace the whole command for test purposes.
    GDB_CMD="echo \"Simulating GDB_CMD failure...\" && bash -c 'exit 123'"
  fi

  if false; then
    # Replace the whole command for test purposes.
    GDB_CMD="echo \"Simulating GDB_CMD death by signal...\" && bash -c 'kill -USR1 \$\$'"
  fi

  echo
  echo "Running debugger script:"
  echo "$GDB_CMD"

  set +o errexit
  eval "$GDB_CMD"
  local GDB_CMD_EXIT_CODE="$?"
  set -o errexit

  if (( GDB_CMD_EXIT_CODE != 0 )); then
    abort "The debugger script failed with an exit code of $GDB_CMD_EXIT_CODE."
  fi


  echo
  echo "The debugger script has terminated. Shutting down OpenOCD..."

  if false; then

    # OpenOCD provides no clean way to shut it down from outside. A workaround is to use telnet.
    # Unfortunately, the shutdown operation does not wait until the telnet connection has been closed,
    # so telnet fails with a non-zero exit code. Therefore, I am using the alternative further below.

    echo "shutdown" | telnet localhost 4444 >/dev/null

  else

    # This is not a clean telnet connection, because we actually do not implement the telnet protocol
    # in the connection below, but it is enough to get the 'shutdown' command through.

    local TELNET_CONNECTION

    exec {TELNET_CONNECTION}>/dev/tcp/localhost/4444

    printf "shutdown\\n" >&${TELNET_CONNECTION}

    # With a command like this we could print any reply the telnet server printed.
    # The trouble is, the first bytes will show some rubbish, because they are actually an attempt to negotiate
    # a Telnet protocol connection.
    if false; then
      cat <&${TELNET_CONNECTION}
    fi

    exec {TELNET_CONNECTION}<&-

  fi


  echo "Waiting for the OpenOCD child process to terminate..."

  set +o errexit
  local OPENOCD_EXIT_CODE
  wait "$OPEN_OCD_JOB_SPEC"
  OPENOCD_EXIT_CODE="$?"
  set -o errexit

  if (( OPENOCD_EXIT_CODE != 0 )); then
    # Use OpenOCD command "shutdown error" to test this error handling logic.
    abort "OpenOCD failed with exit code $OPENOCD_EXIT_CODE."
  fi

  echo "The debug session terminated successfully."
}


check_open_ocd_version ()
{
  # OpenOCD versions older than 0.10.0 will probably not work well.
  local -r OPENOCD_MINIMUM_VERSION="0.10.0"
  local -r OPENOCD_VERSION_0_11_0="0.11.0"
  local -r OPENOCD_VERSION_0_12_0="0.12.0"

  echo "Checking that OpenOCD is at least version $OPENOCD_MINIMUM_VERSION..."

  local VERSION_INFO_CMD=""

  quote_and_append_args  VERSION_INFO_CMD  "$PATH_TO_OPENOCD"
  quote_and_append_args  VERSION_INFO_CMD  "--version"

  local OPENOCD_VERSION_TEXT
  local OPENOCD_EXIT_CODE

  set +o errexit
  # Note that OpenOCD outputs the text to stderr
  OPENOCD_VERSION_TEXT="$(eval "$VERSION_INFO_CMD" 2>&1)"
  OPENOCD_EXIT_CODE="$?"
  set -o errexit

  if (( OPENOCD_EXIT_CODE != 0 )); then
    abort "Cannot run OpenOCD, the error was: $OPENOCD_VERSION_TEXT."
  fi

  local OPENOCD_VERSION_REGEX="Open On-Chip Debugger ([[:digit:]]+.[[:digit:]]+.[[:digit:]]+)"
  local OPENOCD_VERSION_NUMBER_FOUND

  if [[ $OPENOCD_VERSION_TEXT =~ $OPENOCD_VERSION_REGEX ]]; then
    OPENOCD_VERSION_NUMBER_FOUND="${BASH_REMATCH[1]}"
  else
    abort "Could not determine OpenOCD's version number from the following version information text:"$'\n'"$OPENOCD_VERSION_TEXT"
  fi

  echo "OpenOCD version found: $OPENOCD_VERSION_NUMBER_FOUND"

  local -r CHECK_VERSION_TOOL="$DEBUGDUE_ROOT_DIR/Tools/CheckVersion.sh"


  local IS_VER_0_12_0_OR_HIGHER_BOOL

  IS_VER_0_12_0_OR_HIGHER_BOOL="$("$CHECK_VERSION_TOOL" --result-as-text "OpenOCD" "$OPENOCD_VERSION_NUMBER_FOUND" ">=" "$OPENOCD_VERSION_0_12_0")"

  case "$IS_VER_0_12_0_OR_HIGHER_BOOL" in
    true)  IS_OPEN_OCD_VERSION_0_11_0_OR_HIGHER=true
           IS_OPEN_OCD_VERSION_0_12_0_OR_HIGHER=true
           return;;
    false) IS_OPEN_OCD_VERSION_0_12_0_OR_HIGHER=false;;
    *) abort "Tool \"$CHECK_VERSION_TOOL\" returned invalid answer \"$IS_VER_0_12_0_OR_HIGHER_BOOL\"."
  esac


  local IS_VER_0_11_0_OR_HIGHER_BOOL

  IS_VER_0_11_0_OR_HIGHER_BOOL="$("$CHECK_VERSION_TOOL" --result-as-text "OpenOCD" "$OPENOCD_VERSION_NUMBER_FOUND" ">=" "$OPENOCD_VERSION_0_11_0")"

  case "$IS_VER_0_11_0_OR_HIGHER_BOOL" in
    true)  IS_OPEN_OCD_VERSION_0_11_0_OR_HIGHER=true
           return;;
    false) IS_OPEN_OCD_VERSION_0_11_0_OR_HIGHER=false;;
    *) abort "Tool \"$CHECK_VERSION_TOOL\" returned invalid answer \"$IS_VER_0_11_0_OR_HIGHER_BOOL\"."
  esac

  "$CHECK_VERSION_TOOL" "OpenOCD" "$OPENOCD_VERSION_NUMBER_FOUND" ">=" "$OPENOCD_MINIMUM_VERSION"
}


do_program_and_debug ()
{
  check_open_ocd_version

  local TMP_STR

  local OPEN_OCD_CMD=""

  quote_and_append_args OPEN_OCD_CMD "$PATH_TO_OPENOCD"

  if false; then
    # The default is debug level 2. Level 3 is too verbose and slows execution down considerably.
    quote_and_append_args OPEN_OCD_CMD "--debug=3"
  fi

  if $IS_OPEN_OCD_VERSION_0_11_0_OR_HIGHER; then
    add_openocd_cmd "set ::DebugDue_IsOpenOcdVersion_0_11_0_OrHigher 1"
  else
    add_openocd_cmd "set ::DebugDue_IsOpenOcdVersion_0_11_0_OrHigher 0"
  fi

  if $IS_OPEN_OCD_VERSION_0_12_0_OR_HIGHER; then
    add_openocd_cmd "set ::DebugDue_IsOpenOcdVersion_0_12_0_OrHigher 1"
  else
    add_openocd_cmd "set ::DebugDue_IsOpenOcdVersion_0_12_0_OrHigher 0"
  fi

  # OpenOCD's documentation states the following:
  #   By default, OpenOCD will listen on the loopback interface only.
  # But my OpenOCD version 0.10.0 is listening on all IP addresses, which makes it a security risk.
  # Therefore, force localhost-only listening here.
  add_openocd_cmd "bindto localhost"

  case "$DEBUG_ADAPTER" in
    DebugDue)
      printf -v TMP_STR  "set DEBUGDUE_SERIAL_PORT %q"  "$DEBUGDUE_SERIAL_PORT"
      add_openocd_cmd "$TMP_STR"
      quote_and_append_args OPEN_OCD_CMD "--file" "$OPENOCD_CONFIG_DIR/DebugDueInterfaceConfig.tcl"
      ;;

    Flyswatter2)
      quote_and_append_args OPEN_OCD_CMD  "--file" "interface/ftdi/flyswatter2.cfg"

      # TDO is actually valid on the falling edge of the clock.
      if $IS_OPEN_OCD_VERSION_0_12_0_OR_HIGHER; then
        add_openocd_cmd "ftdi tdo_sample_edge falling"
      else
        add_openocd_cmd "ftdi_tdo_sample_edge falling"
      fi
      ;;

    Olimex-ARM-USB-OCD-H)
      quote_and_append_args OPEN_OCD_CMD  "--file" "interface/ftdi/olimex-arm-usb-ocd-h.cfg"

      # Prevent the following log information line by explicitly selecting the transport here.
      #   Info : auto-selecting first available session transport "jtag". To override use 'transport select <transport>'.
      add_openocd_cmd "transport select jtag"

      # TDO is actually valid on the falling edge of the clock.
      if $IS_OPEN_OCD_VERSION_0_12_0_OR_HIGHER; then
        add_openocd_cmd "ftdi tdo_sample_edge falling"
      else
        add_openocd_cmd "ftdi_tdo_sample_edge falling"
      fi
      ;;

    *) abort "Invalid DEBUG_ADAPTER value of \"$DEBUG_ADAPTER\"." ;;
  esac

  quote_and_append_args OPEN_OCD_CMD "--file" "target/at91sam3ax_8x.cfg"

  quote_and_append_args OPEN_OCD_CMD "--file" "$OPENOCD_CONFIG_DIR/OpenOcdJtagConfig.tcl"

  # Set the JTAG clock speed. If you try to set the speed earlier, it gets overridden
  # back to 500 KHz, at least with the Flyswatter2.
  #
  # About the connection speed:
  #   The maximum JTAG speed for this kind of microcontroller is F_CPU/6.
  #   The SAM3X starts at 4 MHz upon reset, so that maximum JTAG speed on start-up is 666 kHz.
  #   However, the standard OpenOCD configuration sets the JTAG speed to 500 kHz,
  #   because the internal oscillator may not be very accurate.
  #   The flash write speed is then around 13 kBytes/s.
  #   We could increase the CPU clock temporarily before flashing the firmware in order to save time.
  #
  #   If the CPU is running at the normal speed of 84 MHz, the maximum JTAG clock would be 14 MHz then.
  #   If the firmware from this project has been programmed already, you can use that maximum speed,
  #   because the firmware increases F_CPU to 84 MHz on start-up before the short pause
  #   for the eventual OpenOCD connection. There are some gotchas though:
  #   - We cannot be sure that the firmware has actually increased the CPU clock.
  #   - We are resetting now with software (instead of with the hardware SRST signal),
  #     so the firmware will not run at all upon reset.
  #
  #   Note that high speeds may not be reliable, especially if you use non-professional cables.
  #   You can use command-line option '--verify' (at the cost of a short extra delay)
  #   to make sure that you can trust your setup.
  #   Speeds over 10 MHz do not really bring any advantage, as the Flash memory becomes then the bottleneck.
  local -r -i ADAPTER_SPEED_KHZ="500"

  case "$DEBUG_ADAPTER" in

    DebugDue)
      # The DebugDue software has no speed control yet.
      ;;

    Olimex-ARM-USB-OCD-H)
      # About RTCK/RCLK:
      #
      #   Enabling RTCK/RCLK (with "adapter_khz 0" or "adapter speed 0") makes the adapter hang. The red LED
      #   remains on and you have to unplug and reconnect the USB cable in order for the adapter to work again.
      #
      #   The Olimex-ARM-USB-OCD-H states that it does support "adaptive clocking RTCK",
      #   but the SAM3X microcontroller on the Arduino Due provides no RTCK signal.
      #
      #   Other microcontrollers, like the Atmel SAM9XE series, do have an RTCK signal.
      #   The Atmel SAM9XE series have an ARM926EJ-S core, not a Cortex-Mx core.
      #
      #   According to TI: "The ARM Cortex M4, R4, or A8 cores do not have RTCK".
      #   I guess that Cortex-M3 does not have it either.
      #
      #  The JTAG connector on the Arduino Due, a 10-Pin Cortex Debug Connector, does not have a RTCK/RCLK pin.
      if $IS_OPEN_OCD_VERSION_0_11_0_OR_HIGHER; then
        add_openocd_cmd "adapter speed $ADAPTER_SPEED_KHZ"
      else
        add_openocd_cmd "adapter_khz $ADAPTER_SPEED_KHZ"
      fi
      ;;

    Flyswatter2)
      # Enabling RTCK/RCLK (with "adapter_khz 0") makes the Adapter hang.
      # See the notes above in the Olimex-ARM-USB-OCD-H section for more information about the debug adapter speed.
      if $IS_OPEN_OCD_VERSION_0_11_0_OR_HIGHER; then
        add_openocd_cmd "adapter speed $ADAPTER_SPEED_KHZ"
      else
        add_openocd_cmd "adapter_khz $ADAPTER_SPEED_KHZ"
      fi
      ;;

    *) abort "Invalid DEBUG_ADAPTER value of \"$DEBUG_ADAPTER\"." ;;
  esac

  add_openocd_cmd "init"

  if $PROGRAM_OVER_JTAG_SPECIFIED; then

    if $SAME_FILE_THEREFORE_SKIP_PROGRAMMING; then
      add_openocd_cmd_echo "Skipping programming, as it is the same binary file as the last time around. In order to force programming, delete the cached file:"
      add_openocd_cmd_echo "  $CACHED_PROGRAMMED_FILE_FILENAME"
    else
      local FLASH_ADDR="0x00080000"

      add_openocd_cmd "arduino_due_reset_and_halt"

      # Delete the old cached file in case programming fails, and you end up with a corrupt firmware on the target.
      if $CACHE_FILE_EXISTS_BUT_DIFFERENT; then
        add_openocd_cmd_echo "Deleting old bin cache file \"$CACHED_PROGRAMMED_FILE_FILENAME\"..."

        printf -v TMP_STR  "file delete %q"  "$CACHED_PROGRAMMED_FILE_FILENAME"
        add_openocd_cmd "$TMP_STR"
      fi


      add_openocd_cmd_echo "Flashing file \"$BIN_FILEPATH\"..."

      # Command 'flash write_image' prints the write speed to the console,
      # but if we calculate the speed ourselves, we can programmatically check later on
      # whether the flash speed has decreased, for example after making changes to this script.
      local -r MEASURE_TIME=false

      if $MEASURE_TIME; then
        add_openocd_cmd "set fileStats [file stat $BIN_FILEPATH]"
        add_openocd_cmd "set fileSize \$fileStats(size)"

        # Store the start time in order to calculate the duration later on.
        # This measurement is unreliable: it will not work properly if the realtime clock is adjusted in the meantime.
        # For example, the ntpd daemon automatically adjusts the clock all the time,
        # in order to keep it synchronised with an external source.
        # We should take 'os.uptime' instead, but its resolution is only 1 second, so not enough for our purposes.
        # Alas, reading a more accurate uptime in OpenOCD's Tcl is hard.

        add_openocd_cmd "set startTime [clock milliseconds]"
      fi

      printf -v TMP_STR  "flash write_image erase %q %q" "$BIN_FILEPATH" "$FLASH_ADDR"
      add_openocd_cmd "$TMP_STR"

      if $MEASURE_TIME; then
        add_openocd_cmd "set elapsedMs [ expr { [clock milliseconds] - \$startTime } ]"
        add_openocd_cmd "echo [ format \"Flashed in %d,%03d s at %d kB/s.\" [expr { \$elapsedMs / 1000 }]  [expr { \$elapsedMs % 1000 }]  [expr { \$fileSize / \$elapsedMs }] ]"
      fi

      if $VERIFY_SPECIFIED; then

        add_openocd_cmd_echo "Verifying file \"$BIN_FILEPATH\" at addr $FLASH_ADDR..."

        # Both 'verify_image' and 'verify_image_checksum' take a while to run, depending on the CPU frequency.
        # They both take the same time, at least when the verification succeeds (which should always be the case).
        printf -v TMP_STR  "verify_image %q %q" "$BIN_FILEPATH" "$FLASH_ADDR"
        add_openocd_cmd "$TMP_STR"

      fi

      if $CACHE_PROGRAMMED_FILE_SPECIFIED; then
        add_openocd_cmd_echo "Keeping a copy of programmed file \"$BIN_FILEPATH\" at \"$CACHED_PROGRAMMED_FILE_FILENAME\" ..."
        printf -v TMP_STR  "file copy -force %q %q" "$BIN_FILEPATH" "$CACHED_PROGRAMMED_FILE_FILENAME"
        add_openocd_cmd "$TMP_STR"
      fi
    fi

    if ! $DEBUG_SPECIFIED; then
      add_openocd_cmd "reset run"
      add_openocd_cmd "shutdown"
    fi
  fi

  if $DEBUG_SPECIFIED; then
    debug_target
  else
    echo "$OPEN_OCD_CMD"
    eval "$OPEN_OCD_CMD"
  fi
}


do_run_in_qemu ()
{
  # Build the GDB command upfront. If something is wrong, it is not worth starting Qemu.
  local GDB_CMD
  build_gdb_command "QEMU"


  local -r QEMU_TOOL="qemu-system-arm"

  # This check is not strictly necessary, but Qemu is not usually installed by default
  # and it provides a more user-friendly error message. We could even suggest
  # the Ubunut/Debian package to install.
  if ! type "$QEMU_TOOL" >/dev/null 2>&1 ;
  then
    abort "Could not find Qemu program \"$QEMU_TOOL\"."
  fi

  local QEMU_CMD=""

  quote_and_append_args  QEMU_CMD  "$QEMU_TOOL"

  quote_and_append_args  QEMU_CMD  "-cpu"  "cortex-m3"

  if false; then
    # KVM only helps if the host CPU is similar to the target CPU. This is probably not going to be the case
    # in our embedded ARM CPU.
    # We could leave this option enabled, just in case, but then you will probably get the following warning every time:
    #   qemu-system-arm: -machine accel=kvm: No accelerator found
    quote_and_append_args  QEMU_CMD  "-enable-kvm"
  fi

  quote_and_append_args  QEMU_CMD  "-machine"  "lm3s811evb"  # Emulates a Luminary Micro Stellaris LM3S6965EVB.

  quote_and_append_args  QEMU_CMD  "-name"  "Stellaris VM"

  quote_and_append_args  QEMU_CMD  "-net" "none"

  quote_and_append_args  QEMU_CMD  "-nographic"

  quote_and_append_args  QEMU_CMD  "-semihosting"

  # OpenOCD uses port number 3333 by default, so use the same port here. If you wish to change it,
  # you will need to pass it as an argument to script DebuggerStarterHelper.sh too.
  local -r GDB_PORT_NUMBER="3333"

  quote_and_append_args  QEMU_CMD  "-gdb"  "tcp::$GDB_PORT_NUMBER"

  quote_and_append_args  QEMU_CMD  -S  # Do not start the CPU, wait for GDB to connect.

  quote_and_append_args  QEMU_CMD  -kernel  "$ELF_FILEPATH"


  echo "Starting Qemu with command:"
  echo "$QEMU_CMD"
  echo
  eval "$QEMU_CMD" &


  # There is no way to determine when QEMU has started and is ready to accept
  # an incoming GDB connection. I asked on the QEMU mailing list to no avail:
  #   Automating Qemu and GDB together
  #   09 May 2020
  #   https://mail.gnu.org/archive/html/qemu-discuss/2020-05/msg00013.html
  # It turns out that GDB retries the TCP connection by default, see GDB commands
  # "show tcp auto-retry" and "show tcp connect-timeout". Therefore, there is not
  # really an issue to worry about. The only drawback is that, if GDB fails
  # to connect the first time around, it will waste some time between retries,
  # but that has not been a big problem yet.

  # Routine check_background_job_still_running needs a temporary directory.
  local PROJECT_OBJ_DIR_TMP="$PROJECT_OBJ_DIR/tmp"
  mkdir --parents -- "$PROJECT_OBJ_DIR_TMP"

  # This first check will probably always succeed. If the child process has terminated,
  # we will find out the next time around. We are doing an initial check
  # in order to extract the exact job ID. Bash provides no other way to
  # get the job spec, as far as I can tell. Using the "last job" spec %%
  # is risky, because something else may start another job in the meantime.
  local LAST_JOB_STATUS=""
  check_background_job_still_running %%
  parse_job_id "$LAST_JOB_STATUS"
  local QEMU_JOB_SPEC="$CAPTURED_JOB_SPEC"

  echo
  echo "Running debugger script:"
  echo "$GDB_CMD"

  set +o errexit
  eval "$GDB_CMD"
  local GDB_CMD_EXIT_CODE="$?"
  set -o errexit

  if (( GDB_CMD_EXIT_CODE != 0 )); then
    abort "The debugger script failed with an exit code of $GDB_CMD_EXIT_CODE."
  fi

  echo
  echo "The debugger script has terminated. Shutting down Qemu..."

  # There are other ways to terminate Qemu. We could use SIGINT instead of SIGTERM.
  # Or we could connect to the operating system inside (if there is one) and issue a shutdown
  # from within the VM. But that does not apply here, as we are debugging the VM and it could
  # be frozen at this time, for example, in a breakpoint.
  # Alternatively, we could connect to Qemu's monitor socket and send command "system_powerdown",
  # see Qemu options '-monitor' and '-qmp'.
  kill -s SIGTERM  "$QEMU_JOB_SPEC"

  echo "Waiting for the Qemu child process to terminate..."

  set +o errexit
  local QEMU_EXIT_CODE
  wait "$QEMU_JOB_SPEC"
  QEMU_EXIT_CODE="$?"
  set -o errexit

  if (( QEMU_EXIT_CODE != 0 )); then
    abort "Qemu failed with exit code $QEMU_EXIT_CODE."
  fi

  echo "The debug session terminated successfully."
}


# ------- Entry point -------

get_uptime
UPTIME_BEGIN="$CURRENT_UPTIME"

user_config

TOOLCHAIN_DIR="$DEFAULT_TOOLCHAIN_DIR"
ASF_DIR=""
PATH_TO_OPENOCD="$DEFAULT_PATH_TO_OPENOCD"
BUILD_TYPE="$DEFAULT_BUILD_TYPE"
DEBUGGER_TYPE="$DEFAULT_DEBUGGER_TYPE"
PATH_TO_BOSSAC="$DEFAULT_PATH_TO_BOSSAC"
BUILD_OUTPUT_BASE_DIR="$DEFAULT_BUILD_OUTPUT_BASE_DIR"
DEBUG_ADAPTER="$DEFAULT_DEBUG_ADAPTER"


USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [clean]=0 )
USER_LONG_OPTIONS_SPEC+=( [enable-configure-cache]=0 )
USER_LONG_OPTIONS_SPEC+=( [build]=0 )
USER_LONG_OPTIONS_SPEC+=( [enable-ccache]=0 )
USER_LONG_OPTIONS_SPEC+=( [install]=0 )
USER_LONG_OPTIONS_SPEC+=( [disassemble]=0 )
USER_LONG_OPTIONS_SPEC+=( [program-over-jtag]=0 )
USER_LONG_OPTIONS_SPEC+=( [program-with-bossac]=0 )
USER_LONG_OPTIONS_SPEC+=( [verify]=0 )
USER_LONG_OPTIONS_SPEC+=( [cache-programmed-file]=0 )
USER_LONG_OPTIONS_SPEC+=( [debug]=0 )
USER_LONG_OPTIONS_SPEC+=( [debug-from-the-start]=0 )
USER_LONG_OPTIONS_SPEC+=( [show-build-commands]=0 )
USER_LONG_OPTIONS_SPEC+=( [build-type]=1 )
USER_LONG_OPTIONS_SPEC+=( [toolchain-dir]=1 )
USER_LONG_OPTIONS_SPEC+=( [atmel-software-framework]=1 )
USER_LONG_OPTIONS_SPEC+=( [openocd-path]=1 )
USER_LONG_OPTIONS_SPEC+=( [debugger-type]=1 )
USER_LONG_OPTIONS_SPEC+=( [add-breakpoint]=1 )
USER_LONG_OPTIONS_SPEC+=( [path-to-bossac]=1 )
USER_LONG_OPTIONS_SPEC+=( [configure-cache-filename]=1 )
USER_LONG_OPTIONS_SPEC+=( [project]=1 )
USER_LONG_OPTIONS_SPEC+=( [make-arg]=1 )
USER_LONG_OPTIONS_SPEC+=( [build-output-base-dir]=1 )
USER_LONG_OPTIONS_SPEC+=( [debug-adapter]=1 )


CLEAN_SPECIFIED=false
VERIFY_SPECIFIED=false
ENABLE_CONFIGURE_CACHE_SPECIFIED=false
CONFIGURE_CACHE_FILENAME=""
BUILD_SPECIFIED=false
ENABLE_CCACHE_SPECIFIED=false
INSTALL_SPECIFIED=false
DISASSEMBLE_SPECIFIED=false
PROGRAM_OVER_JTAG_SPECIFIED=false
PROGRAM_WITH_BOSSAC_SPECIFIED=false
CACHE_PROGRAMMED_FILE_SPECIFIED=false
DEBUG_SPECIFIED=false
DEBUG_FROM_THE_START_SPECIFIED=false
SHOW_BUILD_COMMANDS=false
PROJECT="$DEFAULT_PROJECT"
declare -ag BREAKPOINTS=()
declare -ag EXTRA_MAKE_ARGS=()

parse_command_line_arguments "$@"

if [ ${#ARGS[@]} -ne 0 ]; then
  abort "Invalid number of command-line arguments. Run this script without arguments for help."
fi


if $CLEAN_SPECIFIED || \
   $BUILD_SPECIFIED || \
   $INSTALL_SPECIFIED || \
   $PROGRAM_OVER_JTAG_SPECIFIED || \
   $PROGRAM_WITH_BOSSAC_SPECIFIED || \
   $DEBUG_SPECIFIED; then
  :
else
  abort "No operation requested. Specify --help for usage information."
fi

check_only_one "Only one build operation can be specified." $BUILD_SPECIFIED $INSTALL_SPECIFIED

check_only_one "Only one program operation can be specified." $PROGRAM_OVER_JTAG_SPECIFIED $PROGRAM_WITH_BOSSAC_SPECIFIED

DEBUGDUE_ROOT_DIR="$(readlink --verbose --canonicalize -- "$PWD")"
PROJECT_SRC_DIR="$DEBUGDUE_ROOT_DIR/Project"

case "${BUILD_TYPE}" in
  debug)   PROJECT_OBJ_DIR_SUFFIX="debug"   ;;
  release) PROJECT_OBJ_DIR_SUFFIX="release" ;;
  *) abort "Invalid build type of \"$BUILD_TYPE\"." ;;
esac


PROJECT_NAME_LOWERCASE="${PROJECT,,}"

case "${PROJECT_NAME_LOWERCASE}" in
  debugdue)       PROJECT_NAME="DebugDue" ;;
  emptyfirmware) PROJECT_NAME="EmptyFirmware" ;;
  qemufirmware) PROJECT_NAME="QemuFirmware" ;;
  *) abort "Invalid project name \"$PROJECT\"." ;;
esac


PROJECT_OBJ_DIR="$BUILD_OUTPUT_BASE_DIR/$PROJECT_NAME-obj-$PROJECT_OBJ_DIR_SUFFIX"
PROJECT_BIN_DIR="$BUILD_OUTPUT_BASE_DIR/$PROJECT_NAME-bin-$PROJECT_OBJ_DIR_SUFFIX"

CACHED_PROGRAMMED_FILE_FILENAME="$BUILD_OUTPUT_BASE_DIR/CachedProgrammedFile.bin"

DEFAULT_CONFIGURE_CACHE_FILENAME="$BUILD_OUTPUT_BASE_DIR/config.cache"

if $ENABLE_CONFIGURE_CACHE_SPECIFIED; then
  if [[ $CONFIGURE_CACHE_FILENAME = "" ]]; then
    CONFIGURE_CACHE_FILENAME="$DEFAULT_CONFIGURE_CACHE_FILENAME"
  fi
fi

TARGET_ARCH="arm-none-eabi"

if $BUILD_SPECIFIED || $INSTALL_SPECIFIED; then
  NEED_TOOLCHAIN=true
else
  NEED_TOOLCHAIN=false
fi

if $NEED_TOOLCHAIN; then
  PATH="$TOOLCHAIN_DIR/bin:$PATH"
  check_whether_compiler_is_present
fi


CONFIGURE_SCRIPT_PATH="$PROJECT_SRC_DIR/configure"

# Convert to lowercase.
DEBUGGER_TYPE="${DEBUGGER_TYPE,,}"

BIN_FILENAME="firmware"

BIN_FILEPATH="$PROJECT_OBJ_DIR/$BIN_FILENAME.bin"
ELF_FILEPATH="$PROJECT_OBJ_DIR/$BIN_FILENAME.elf"

OPENOCD_CONFIG_DIR="$DEBUGDUE_ROOT_DIR/OpenOCD/SecondArduinoDueAsTarget"

if $VERIFY_SPECIFIED && ! $PROGRAM_OVER_JTAG_SPECIFIED && ! $PROGRAM_WITH_BOSSAC_SPECIFIED ; then
  abort "Option '--verify' specified, but no programming operation requested."
fi


# ---------  Step 1: Clean ---------

if $CLEAN_SPECIFIED; then
  do_clean
fi


# ---------  Step 2: Build ---------

if $BUILD_SPECIFIED || $INSTALL_SPECIFIED; then
  do_autogen_if_necessary

  create_dir_if_not_exists "$PROJECT_OBJ_DIR"

  do_configure_if_necessary

  do_build
fi


# ---------  Step 3 and 4: Program and Debug ---------

if [[ $PROJECT_NAME_LOWERCASE = "qemufirmware" ]]; then

  if $PROGRAM_OVER_JTAG_SPECIFIED || $PROGRAM_WITH_BOSSAC_SPECIFIED; then
    abort "Cannot program a Qemu firmware. You can only run it with option '--debug'."
  fi

  if $DEBUG_SPECIFIED; then
    do_run_in_qemu
  fi

else

  SAME_FILE_THEREFORE_SKIP_PROGRAMMING=false
  CACHE_FILE_EXISTS_BUT_DIFFERENT=false

  if $PROGRAM_OVER_JTAG_SPECIFIED || $PROGRAM_WITH_BOSSAC_SPECIFIED; then

    if $CACHE_PROGRAMMED_FILE_SPECIFIED; then
      if [ -e "$CACHED_PROGRAMMED_FILE_FILENAME" ]; then
        set +o errexit
        cmp --quiet "$CACHED_PROGRAMMED_FILE_FILENAME" "$BIN_FILEPATH"
        CMP_EXIT_CODE="$?"
        set -o errexit

        case "$CMP_EXIT_CODE" in
          0) SAME_FILE_THEREFORE_SKIP_PROGRAMMING=true;;
          1) CACHE_FILE_EXISTS_BUT_DIFFERENT=true;;
          *) abort "Error comparing files \"$CACHED_PROGRAMMED_FILE_FILENAME\" and \"$BIN_FILEPATH\", cmp exited with a status code of $CMP_EXIT_CODE";;
        esac
      fi
    else
      delete_file_if_exists "$CACHED_PROGRAMMED_FILE_FILENAME"
    fi

  fi

  if $PROGRAM_OVER_JTAG_SPECIFIED || $DEBUG_SPECIFIED; then
    do_program_and_debug
  fi

  if $PROGRAM_WITH_BOSSAC_SPECIFIED; then
    do_bossac
  fi

fi

get_uptime

# We are using here external tool 'bc' because Bash does not support floating-point numbers.
# It is possible to write a pure-Bash implementation with a precision to the hundredth of a second,
# but, if you are not careful, 32-bit versions of Bash could fail if the uptime is greater than 248 days.
# I could not find the time to write such a careful implementation.
#
# Apparently, bc's variable 'scale' only works with division, for other operations the displayed precision
# will depend on the operands. That is the reason why the result is divided by 1 at the end.
#
# At this point, we could try to find out the integer width of the current Bash version
# and check that bc's result does not overflow it. If you have the time to implement it,
# please drop me a line.
ELAPSED_TIME="$(bc <<< "result = ($CURRENT_UPTIME - $UPTIME_BEGIN)*100; scale=0; result/1")"

generate_elapsed_time_msg "$ELAPSED_TIME"

echo "All $SCRIPT_NAME operations done in $ELAPSED_TIME_MSG."

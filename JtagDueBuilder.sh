#!/bin/bash

# Copyright (c) 2014-2018 R. Diez - Licensed under the GNU AGPLv3 - see below for more information.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


user_config ()
{
  DEFAULT_TOOLCHAIN_DIR="$HOME/SomeDir/JtagDueToolchain"

  DEFAULT_ASF_DIR="$HOME/SomeDir/asf-standalone-archive-3.19.0.95"

  DEFAULT_PATH_TO_OPENOCD="$HOME/SomeDir/openocd-0.8.0-bin/bin/openocd"

  # This setting only matters when using the 'bossac' tool.
  DEFAULT_PATH_TO_BOSSAC="bossac"

  # This setting only matters when using the 'bossac' tool.
  PROGRAMMING_USB_VIRTUAL_SERIAL_PORT="/dev/serial/by-id/usb-Arduino__www.arduino.cc__Arduino_Due_Prog._Port_7523230323535180A120-if00"

  JTAG_ADAPTER="JtagDue"
  # JTAG_ADAPTER="Flyswatter2"
  # JTAG_ADAPTER="Olimex-ARM-USB-OCD-H"

  # This setting only matters when JTAG_ADAPTER="JtagDue". This is the location of the
  # 'native' USB virtual serial port of the Arduino Due that is acting as a JTAG adapter.
  # OpenOCD will be told that this is where to find the (emulated) Bus Pirate.
  JTAGDUE_SERIAL_PORT="/dev/serial/by-id/usb-Arduino_Due_JTAG_Adapter_JtagDue1-if00"

  DEFAULT_PROJECT="JtagDue"

  DEFAULT_BUILD_TYPE="debug"

  DEFAULT_DEBUGGER_TYPE="gdb"

  OUTPUT_DIR="$(readlink --verbose --canonicalize -- "BuildOutput")"
}


VERSION_NUMBER="1.04"
SCRIPT_NAME="JtagDueBuilder.sh"

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

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014-2017 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script builds/runs/etc. the JtagDue project. You would normally run
the script from your development environment (Emacs, Vim, Eclipse, ...).

Syntax:
  $SCRIPT_NAME <switches...>

Information switches:
 --help     Displays this help text.
 --version  Displays the tool's version number (currently $VERSION_NUMBER).
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
                    See this script's source code for details about ccache.

Step 2, build operations:
  --build    Runs "make" for the default target. Generates the autoconf
             files beforehand if necessary.
  --install  Runs "make install". Normally not needed.
  --atmel-software-framework="<path>"  Directory where the ASF is installed.
  --disassemble  Generate extra information files from the just-built ELF file:
                 complete disassembly, list of objects sorted by size,
                 sorted list of strings (with 'strings' command):

  The default is not to build anything. If you then debug your firmware,
  make sure that the existing binary matches the code on the target.

Step 3, program operations:
  --program-over-jtag  Transfers the firmware over JTAG to the target device.
  --program-with-bossac  Transfers the firmware with 'bossac' to the target device.
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

Step 4, debug operations:
  --debug  Starts the firmware under the debugger (GDB connected to
           OpenOCD over JTAG).
  --debugger-type="<type>"  Debugger types are "gdb" and "ddd" (a graphical
                            interface to GDB).
  --debug-from-the-start  Breaks as soon as possible after starting the firmware.
  --add-breakpoint="function name or line position like Main.cpp:123"
  --openocd-path="openocd-0.8.0/bin/openocd"  Path to the OpenOCD executable.

Global options:
  --project="<project name>"  Specify 'JtagDue' (the default) or 'EmptyFirmware'.
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

    local CONFIG_CMD

    CONFIG_CMD+="CONFIG_SHELL=/bin/bash"
    CONFIG_CMD+=" $CONFIGURE_SCRIPT_PATH"

    if $ENABLE_CONFIGURE_CACHE_SPECIFIED; then
      echo "Using configure cache file \"$CONFIGURE_CACHE_FILENAME\"."
      CONFIG_CMD+=" --cache-file=\"$CONFIGURE_CACHE_FILENAME\""
    else
      # If the cache file to use comes as a command-line argument, then the user
      # is responsible for the cache file's lifetime.
      # This script will only delete its local, default cache file
      # if it has not been told to use it.
      delete_file_if_exists "$DEFAULT_CONFIGURE_CACHE_FILENAME"
    fi

    CONFIG_CMD+=" --prefix=\"$PROJECT_BIN_DIR\""

    if [[ $BUILD_TYPE = debug ]]; then
      CONFIG_CMD+=" --enable-debug=yes"
      # echo "Creating a debug build..."
    else
      CONFIG_CMD+=" --enable-debug=no"
      # echo "Creating a release build..."
    fi

    CONFIG_CMD+=" --with-atmel-software-framework=\"$ASF_DIR\""
    CONFIG_CMD+=" --with-project=\"$PROJECT_NAME\""

    CONFIG_CMD+=" --host=\"$TARGET_ARCH\""
    # I have not figured out yet how to get the value passed as --host to configure.ac ,
    # so I am passing it again in a separate command-line option.
    CONFIG_CMD+=" --with-target-arch=\"$TARGET_ARCH\""

    # Use GCC's wrappers for 'ar' and 'ranlib'. Otherwise, when using the binutils versions directly,
    # they will complain about a missing plug-in to process object files compiled for LTO.
    # These are however no longer needed, because we are not using libtool anymore.
    if false; then
      CONFIG_CMD+=" AR=\"$TARGET_ARCH-gcc-ar\""
      CONFIG_CMD+=" RANLIB=\"$TARGET_ARCH-gcc-ranlib\""
    fi

    if $ENABLE_CCACHE_SPECIFIED; then

      # Do not turn ccache on unconditionally. The price of a cache miss in a normal
      # compilation can be as high as 20 %. There are many more disk writes during
      # compilation and pressure increases on the system's disk cache.
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
      # if your cache hits are high enough. Otherwise, you may have to increase
      # your global cache size, or you'll be losing performance.

      CCACHE_NAME="ccache"
      if type "$CCACHE_NAME" >/dev/null 2>&1 ; then
        CONFIG_CMD+=" CC=\"$CCACHE_NAME $TARGET_ARCH-gcc\""
        CONFIG_CMD+=" CXX=\"$CCACHE_NAME $TARGET_ARCH-g++\""
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


add_toolchain_dir_to_path ()
{
  local TOOLCHAIN_DIR="$1"

  local TOOLCHAIN_BIN_DIR="$TOOLCHAIN_DIR/bin"
  local COMPILER_NAME="$TARGET_ARCH-gcc"

  PATH="$TOOLCHAIN_BIN_DIR:$PATH"

  # If you don't get the PATH right, the ./configure script will not find the right compiler,
  # and the error message you'll get much further down is not immediately obvious.
  # Therefore, check beforehand that we do find the right compiler.
  if ! type "$COMPILER_NAME" >/dev/null 2>&1 ;
  then
    abort "Could not find compiler \"$COMPILER_NAME\", did you get the toolchain path right? I am using: $TOOLCHAIN_DIR"
  fi
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

    clean) CLEAN_SPECIFIED=true;;

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

    project)
        PROJECT="$OPTARG"
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
      printf -- "- %s=%s\n" "$key" "${USER_LONG_OPTIONS_SPEC[$key]}"
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
    MAKE_CMD+=" -j \"$MAKE_J_VAL\""
  fi
}


do_build ()
{
  pushd "$PROJECT_OBJ_DIR" >/dev/null

  local MAKE_CMD="make "

  if false; then
    # Possible flags:
    #   a for all
    #   b for basic debugging
    #   v for more verbose basic debugging
    #   i for showing implicit rules
    #   j for details on invocation of commands
    #   m for debugging while remaking makefiles.
    local DEBUG_FLAGS="a"
    MAKE_CMD+=" --debug=$DEBUG_FLAGS"
  fi

  # Normally, the build commands are not shown, see AM_SILENT_RULES in configure.ac .
  # Passing "V=1" in CPPFLAGS is not enough, you need to remove "-s" too.
  local SHOW_BUILD_COMMANDS=false
  if $SHOW_BUILD_COMMANDS; then
    MAKE_CMD+=" V=1"
  else
    MAKE_CMD+=" -s"
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
    MAKE_CMD+=" CPPFLAGS=\"$EXTRA_CPPFLAGS${CPPFLAGS:-}\""
  fi

  MAKE_CMD+=" --no-builtin-rules"

  # This requires GNU Make version 4.0 or newer. If you have an older GNU Make, comment this line out:
  MAKE_CMD+=" --output-sync=recurse"

  add_make_parallel_jobs_flag

  local TARGETS=""

  if $INSTALL_SPECIFIED; then
    TARGETS+=" install"
  fi

  if $DISASSEMBLE_SPECIFIED; then
    TARGETS+=" disassemble"
  fi

  MAKE_CMD+=" $TARGETS"

  echo "$MAKE_CMD"
  eval "$MAKE_CMD"

  local PROG_SIZE
  PROG_SIZE="$(stat -c%s "$BIN_FILEPATH")"

  printf "Resulting binary: \"$BIN_FILEPATH\", size: %'d bytes.\n" "$PROG_SIZE"

  popd >/dev/null
}


add_openocd_arg ()
{
  OPEN_OCD_CMD+=" $1"
}


add_openocd_cmd ()
{
  # When running .tcl files, OpenOCD does not print the function results,
  # but when running commands with --command, it does.
  # The following makes every line return an empty list, which then prints nothing,
  # effectively suppressing printing the function result.
  # I have not found a better way yet to achieve this.
  TCL_SUPPRESS_PRINTING_RESULT_SUFFIX="; list"

  local QUOTED
  printf -v QUOTED "%q" "$1 $TCL_SUPPRESS_PRINTING_RESULT_SUFFIX"

  add_openocd_arg "--command $QUOTED"
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

  local SERIAL_PORT_CONFIG_CMD

  # Trigger an erase first. Otherwise, the SAM-BA bootloader will probably not be present
  # on the 'programming' USB virtual serial port and tool 'bossac' will fail.
  SERIAL_PORT_CONFIG_CMD="stty -F \"$PROGRAMMING_USB_VIRTUAL_SERIAL_PORT\" 1200"
  echo "$SERIAL_PORT_CONFIG_CMD"
  eval "$SERIAL_PORT_CONFIG_CMD"

  local CMD
  CMD="\"$PATH_TO_BOSSAC\" --port=\"$PORT_WITHOUT_PREFIX\""
  # bossac's option "--force_usb_port" means "Enable  automatic detection of the target's USB port"
  # and is turned on by default. We are specifying the exact path to the port,
  # so we do not want any guessing.
  CMD+=" --force_usb_port=false"

  # If you suspect your target is not getting flashed correctly, you can
  # turn verification on. It is normally disabled because it takes a long time.
  if false; then
    CMD+=" --verify"
  fi

  CMD+=" --write \"$BIN_FILEPATH\""
  CMD+=" --boot=1"

  # You could make the reset step optional, so that the new firmware does not start immediately.
  if true; then
   CMD+=" --reset"
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
    cp "$BIN_FILEPATH" "$CACHED_PROGRAMMED_FILE_FILENAME"
   fi
}


do_program_and_debug ()
{
  local OPEN_OCD_CMD="\"$PATH_TO_OPENOCD\" "

  if false; then
    # The default is debug level 2. Level 3 is too verbose and slows execution down considerably.
    add_openocd_arg "--debug=3 "
  fi

  case "$JTAG_ADAPTER" in
    JtagDue)
      add_openocd_cmd "set JTAGDUE_SERIAL_PORT \"$JTAGDUE_SERIAL_PORT\""
      add_openocd_arg "-f \"$OPENOCD_CONFIG_DIR/JtagDueInterfaceConfig.cfg\""
      ;;
    Flyswatter2)
      add_openocd_arg "-f \"interface/ftdi/flyswatter2.cfg\""
      ;;
    Olimex-ARM-USB-OCD-H)
      add_openocd_arg "-f \"interface/ftdi/olimex-arm-usb-ocd-h.cfg\""
      ;;
    *) abort "Invalid JTAG_ADAPTER value of \"$JTAG_ADAPTER\"." ;;
  esac

  add_openocd_arg "-f \"target/at91sam3ax_8x.cfg\""

  add_openocd_arg "-f \"$OPENOCD_CONFIG_DIR/OpenOcdJtagConfig.cfg\""

  # Set the JTAG clock speed. If you try to set it speed earlier, it gets overridden
  # back to 500 KHz, at least with the Flyswatter2.
  case "$JTAG_ADAPTER" in
    JtagDue)
      # The JtagDue software has no speed control yet.
      ;;
    Olimex-ARM-USB-OCD-H)
      # TODO: Enabling RTCK/RCLK (with "adapter_khz 0") makes the Adapter hang.
      add_openocd_cmd "adapter_khz 10000"  # It looks like 15 and even 20 MHz works too, but the speed difference with GDB 'load' is very small.
      ;;
    Flyswatter2)
      # Enabling RTCK/RCLK (with "adapter_khz 0") makes the Adapter hang.
      add_openocd_cmd "adapter_khz 10000"  # It looks like 15 and even 20 MHz works too, but the speed difference with GDB 'load' is very small.
      ;;
    *) abort "Invalid JTAG_ADAPTER value of \"$JTAG_ADAPTER\"." ;;
  esac

  add_openocd_cmd "init"

  if $PROGRAM_OVER_JTAG_SPECIFIED; then

    if $SAME_FILE_THEREFORE_SKIP_PROGRAMMING; then
      add_openocd_cmd_echo "Skipping programming, as it is the same binary file as the last time around. In order to force programming, delete the cached file:"
      add_openocd_cmd_echo "  $CACHED_PROGRAMMED_FILE_FILENAME"
    else
      local FLASH_ADDR="0x00080000"

      add_openocd_cmd "my_reset_and_halt"

      # Delete the old cached file in case programming fails, and you end up with a corrupt firmware on the target.
      if $CACHE_FILE_EXISTS_BUT_DIFFERENT; then
        add_openocd_cmd_echo "Deleting old bin cache file \"$CACHED_PROGRAMMED_FILE_FILENAME\"..."
        add_openocd_cmd "file delete \"$CACHED_PROGRAMMED_FILE_FILENAME\""
      fi

      add_openocd_cmd_echo "Flashing file \"$BIN_FILEPATH\"..."
      add_openocd_cmd "flash write_image erase $BIN_FILEPATH $FLASH_ADDR"

      if $CACHE_PROGRAMMED_FILE_SPECIFIED; then
        add_openocd_cmd_echo "Keeping a copy of programmed file \"$BIN_FILEPATH\" at \"$CACHED_PROGRAMMED_FILE_FILENAME\" ..."
        add_openocd_cmd "file copy -force \"$BIN_FILEPATH\" \"$CACHED_PROGRAMMED_FILE_FILENAME\""
      fi
    fi

    if ! $DEBUG_SPECIFIED; then
      add_openocd_cmd "reset run"
      add_openocd_cmd "shutdown"
    fi
  fi

  if $DEBUG_SPECIFIED; then
    add_openocd_arg "-f \"$OPENOCD_CONFIG_DIR/CloseOpenOcdOnGdbDetach.cfg\""

    local BASH_CMD="cd \"$OPENOCD_CONFIG_DIR\" && ./DebuggerStarterHelper.sh"

    if $DEBUG_FROM_THE_START_SPECIFIED; then
      BASH_CMD+=" --debug-from-the-start"
    fi

    if (( ${#BREAKPOINTS[*]} > 0 )); then
      local BP
      for BP in "${BREAKPOINTS[@]}"; do
        BASH_CMD+=" --add-breakpoint \"$BP\""
      done
    fi

    BASH_CMD+=" \"$TOOLCHAIN_DIR\" \"$ELF_FILEPATH\" \"$DEBUGGER_TYPE\""

    local EXEC_CMD
    printf -v EXEC_CMD "bash -c %q" "$BASH_CMD"
    add_openocd_cmd_echo "Running command in background: $EXEC_CMD"
    add_openocd_cmd "exec $EXEC_CMD &"

    # Is there a way in OpenOCD to periodically monitor the child process?
    # If it exits unexpectedly, OpenOCD should automatically quit.
  fi

  echo "$OPEN_OCD_CMD"
  eval "$OPEN_OCD_CMD"
}


# ------- Entry point -------

get_uptime
UPTIME_BEGIN="$CURRENT_UPTIME"

user_config

TOOLCHAIN_DIR="$DEFAULT_TOOLCHAIN_DIR"
ASF_DIR="$DEFAULT_ASF_DIR"
PATH_TO_OPENOCD="$DEFAULT_PATH_TO_OPENOCD"
BUILD_TYPE="$DEFAULT_BUILD_TYPE"
DEBUGGER_TYPE="$DEFAULT_DEBUGGER_TYPE"
PATH_TO_BOSSAC="$DEFAULT_PATH_TO_BOSSAC"


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
USER_LONG_OPTIONS_SPEC+=( [cache-programmed-file]=0 )
USER_LONG_OPTIONS_SPEC+=( [debug]=0 )
USER_LONG_OPTIONS_SPEC+=( [debug-from-the-start]=0 )
USER_LONG_OPTIONS_SPEC+=( [build-type]=1 )
USER_LONG_OPTIONS_SPEC+=( [toolchain-dir]=1 )
USER_LONG_OPTIONS_SPEC+=( [atmel-software-framework]=1 )
USER_LONG_OPTIONS_SPEC+=( [openocd-path]=1 )
USER_LONG_OPTIONS_SPEC+=( [debugger-type]=1 )
USER_LONG_OPTIONS_SPEC+=( [add-breakpoint]=1 )
USER_LONG_OPTIONS_SPEC+=( [path-to-bossac]=1 )
USER_LONG_OPTIONS_SPEC+=( [configure-cache-filename]=1 )
USER_LONG_OPTIONS_SPEC+=( [project]=1 )

CLEAN_SPECIFIED=false
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
PROJECT="$DEFAULT_PROJECT"
declare -ag BREAKPOINTS=()

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

JTAGDUE_ROOT_DIR="$(readlink --verbose --canonicalize -- "$PWD")"
PROJECT_SRC_DIR="$JTAGDUE_ROOT_DIR/Project"

case "${BUILD_TYPE}" in
  debug)   PROJECT_OBJ_DIR_SUFFIX="debug"   ;;
  release) PROJECT_OBJ_DIR_SUFFIX="release" ;;
  *) abort "Invalid build type of \"$BUILD_TYPE\"." ;;
esac


PROJECT_NAME_LOWERCASE="${PROJECT,,}"

case "${PROJECT_NAME_LOWERCASE}" in
  jtagdue)       PROJECT_NAME="JtagDue" ;;
  emptyfirmware) PROJECT_NAME="EmptyFirmware" ;;
  *) abort "Invalid project name of \"$PROJECT\"." ;;
esac


PROJECT_OBJ_DIR="$OUTPUT_DIR/$PROJECT_NAME-obj-$PROJECT_OBJ_DIR_SUFFIX"
PROJECT_BIN_DIR="$OUTPUT_DIR/$PROJECT_NAME-bin-$PROJECT_OBJ_DIR_SUFFIX"

CACHED_PROGRAMMED_FILE_FILENAME="$OUTPUT_DIR/CachedProgrammedFile.bin"

DEFAULT_CONFIGURE_CACHE_FILENAME="$OUTPUT_DIR/config.cache"

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
  add_toolchain_dir_to_path "$TOOLCHAIN_DIR"
fi


CONFIGURE_SCRIPT_PATH="$PROJECT_SRC_DIR/configure"

# Convert to lowercase.
DEBUGGER_TYPE="${DEBUGGER_TYPE,,}"

BIN_FILENAME="firmware"

BIN_FILEPATH="$PROJECT_OBJ_DIR/$BIN_FILENAME.bin"
ELF_FILEPATH="$PROJECT_OBJ_DIR/$BIN_FILENAME.elf"

OPENOCD_CONFIG_DIR="$JTAGDUE_ROOT_DIR/OpenOCD/SecondArduinoDueAsTarget"


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

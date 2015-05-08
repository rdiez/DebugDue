#!/bin/bash

# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3 - see below for more information.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

user_config ()
{
  DEFAULT_TOOLCHAIN_DIR="$HOME/SomeDir/JtagDueToolchain"

  DEFAULT_ASF_DIR="$HOME/SomeDir/asf-standalone-archive-3.19.0.95"

  DEFAULT_PATH_TO_OPENOCD="$HOME/SomeDir/openocd-0.8.0-bin/bin/openocd"

  JTAG_ADAPTER="JtagDue"
  # JTAG_ADAPTER="Flyswatter2"
  # JTAG_ADAPTER="Olimex-ARM-USB-OCD-H"

  # This setting only matters when JTAG_ADAPTER="JtagDue".
  JTAGDUE_SERIAL_PORT="/dev/serial/by-id/usb-Arduino_Due_JTAG_Adapter_JtagDue1-if00"

  DEFAULT_BUILD_TYPE="debug"

  DEFAULT_DEBUGGER_TYPE="gdb"

  OUTPUT_DIR="$(readlink -f "BuildOutput")"

  # Possible Project names are "JtagDue" or "EmptyFirmware".
  # At the moment, both projects are always built together,
  # so this option only has an effect when programming or debugging.
  PROJECT_NAME="EmptyFirmware"
}


VERSION_NUMBER="1.00"
SCRIPT_NAME="JtagDueBuilder.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
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


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

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

Step 1, clean operations:
  --clean  Deletes the -obj and -bin directories for the given build type
           and the 'configure' script, if they exist, so that the
           next build will start from scratch.

Step 2, build operations:
  --build    Runs "make" for the default target. Generates the autoconf
             files beforehand if necessary.
  --install  Runs "make install". Normally not needed.
  --atmel-software-framework="<path>"  Directory where the ASF is installed.

  The default is not to build anything. If you then debug your firmware,
  make sure that the existing binary matches the code on the target.

Step 3, program operations:
  --program  Transfers the firmware over JTAG to the target device.

Step 4, debug operations:
  --debug  Starts the firmware under the debugger (GDB connected to
           OpenOCD over JTAG).
  --debugger-type="<type>"  Debugger types are "gdb" and "ddd" (a graphical
                            interface to GDB).
  --debug-from-the-start  Breaks as soon as possible after starting the firmware.
  --add-breakpoint="function name or line position like Main.cpp:123"
  --openocd-path="openocd-0.8.0/bin/openocd"  Path to the OpenOCD executable.

Global options:
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
    $SCRIPT_NAME --build --build-type="debug" --program --debug

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-arduino at yahoo.de

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

    echo "Finished running the autotools."
  fi
}


do_configure_if_necessary ()
{
  local RUN_CONFIGURE=false
  local MAKEFILE_PATH="$PROJECT_OBJ_DIR/Makefile"

  if ! [ -f "$MAKEFILE_PATH" ]; then
    echo "File \"$MAKEFILE_PATH\" does not exist, running the configure step..."

    pushd "$PROJECT_OBJ_DIR" >/dev/null

    local CONFIG_CMD="$PROJECT_SRC_DIR/configure"
    CONFIG_CMD+=" --prefix=\"$PROJECT_BIN_DIR\""

    if [[ $BUILD_TYPE = debug ]]; then
      CONFIG_CMD+=" --enable-debug=yes"
      # echo "Creating a debug build..."
    else
      CONFIG_CMD+=" --enable-debug=no"
      # echo "Creating a release build..."
    fi

    CONFIG_CMD+=" --with-atmel-software-framework=\"$ASF_DIR\""

    CONFIG_CMD+=" --build=\"$($PROJECT_SRC_DIR/config.guess)\" --host=\"$TARGET_ARCH\""

    echo "$CONFIG_CMD"
    eval "$CONFIG_CMD"

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


read_command_line_switches ()
{
  # The way command-line arguments are parsed below was originally described on the following page,
  # although I had to make a couple of amendments myself:
  #   http://mywiki.wooledge.org/ComplexOptionParsing

  # Use an associative array to declare how many arguments a long option expects.
  # Long options that aren't listed in this way will have zero arguments by default.
  local -A MY_LONG_OPT_SPEC=([build-type]=1 [toolchain-dir]=1 [atmel-software-framework]=1 [openocd-path]=1 [debugger-type]=1 [add-breakpoint]=1)

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  local MY_OPT_SPEC=":-:"

  CLEAN_SPECIFIED=false
  BUILD_SPECIFIED=false
  INSTALL_SPECIFIED=false
  PROGRAM_SPECIFIED=false
  DEBUG_SPECIFIED=false
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

        clean) CLEAN_SPECIFIED=true;;
        build) BUILD_SPECIFIED=true;;
        install) INSTALL_SPECIFIED=true;;
        program) PROGRAM_SPECIFIED=true;;
        debug) DEBUG_SPECIFIED=true;;
        debug-from-the-start) DEBUG_FROM_THE_START_SPECIFIED=true;;

        toolchain-dir)
            if [[ ${OPTARG:-} = "" ]]; then
              abort "The --toolchain-dir option has an empty value."
            fi
            TOOLCHAIN_DIR="$OPTARG"
            ;;

        atmel-software-framework)
            if [[ ${OPTARG:-} = "" ]]; then
              abort "The --atmel-software-framework option has an empty value."
            fi
            ASF_DIR="$OPTARG"
            ;;

        build-type)
            if [[ ${OPTARG:-} = "" ]]; then
              abort "The --build-type option has an empty value."
            fi
            BUILD_TYPE="$OPTARG"
            ;;

        debugger-type)
            if [[ ${OPTARG:-} = "" ]]; then
              abort "The --debugger-type option has an empty value."
            fi
            DEBUGGER_TYPE="$OPTARG"
            ;;

        add-breakpoint)
            if [[ ${OPTARG:-} = "" ]]; then
              abort "The --add-breakpoint option has an empty value."
            fi
            BREAKPOINTS+=("$OPTARG")
            ;;

        openocd-path)
            if [[ ${OPTARG:-} = "" ]]; then
              abort "The --openocd-path option has an empty value."
            fi
            PATH_TO_OPENOCD="$OPTARG"
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

  if [ $# -ne 0 ]; then
    abort "Invalid number of command-line arguments. Run this script without arguments for help."
  fi
}


do_build ()
{
  pushd "$PROJECT_OBJ_DIR" >/dev/null

  local MAKE_CMD="make "

  local SHOW_BUILD_COMMANDS=false

  if $SHOW_BUILD_COMMANDS; then
    MAKE_CMD+=" V=1"
  else
    MAKE_CMD+=" -s"
  fi

  # If you are building from within emacs, GCC will not automatically turn the diagnostics colours on
  # because it is not running on a real console. You can overcome this by enabling colours in emacs'
  # build output window and then setting the following variable to 'true'.
  local FORCE_GCC_DIAGNOSTICS_COLOR=false
  if $FORCE_GCC_DIAGNOSTICS_COLOR; then
    MAKE_CMD+=" CPPFLAGS=\"-fdiagnostics-color=always\""
  fi

  if $INSTALL_SPECIFIED; then
    local TARGET="install"
  else
    local TARGET=""
  fi

  MAKE_J_VAL="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"

  MAKE_CMD+=" --no-builtin-rules  -j \"$MAKE_J_VAL\" $TARGET"

  echo "$MAKE_CMD"
  eval "$MAKE_CMD"

  local PROG_SIZE="$(stat -c%s $BIN_FILEPATH)"

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

  local QUOTED="$(printf "%q" "$1 $TCL_SUPPRESS_PRINTING_RESULT_SUFFIX")"

  add_openocd_arg "--command $QUOTED"
}


add_openocd_cmd_echo ()
{
  local QUOTED="$(printf "%q" "$1")"

  add_openocd_cmd "echo $QUOTED"
}


do_program_and_debug ()
{
  local OPEN_OCD_CMD="\"$PATH_TO_OPENOCD\" "

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

  if $PROGRAM_SPECIFIED; then
    local FLASH_ADDR="0x00080000"
    add_openocd_cmd "my_reset_and_halt"
    add_openocd_cmd_echo "Flashing file \"$BIN_FILEPATH\"..."
    add_openocd_cmd "flash write_image erase $BIN_FILEPATH $FLASH_ADDR"

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

    local EXEC_CMD="$(printf "bash -c %q" "$BASH_CMD")"
    add_openocd_cmd_echo "Running command in background: $EXEC_CMD"
    add_openocd_cmd "exec $EXEC_CMD &"

    # Is there a way in OpenOCD to periodically monitor the child process?
    # If it exits unexpectedly, OpenOCD should automatically quit.
  fi

  echo "$OPEN_OCD_CMD"
  eval "$OPEN_OCD_CMD"
}


# ------- Entry point -------

user_config

TOOLCHAIN_DIR="$DEFAULT_TOOLCHAIN_DIR"
ASF_DIR="$DEFAULT_ASF_DIR"
PATH_TO_OPENOCD="$DEFAULT_PATH_TO_OPENOCD"
BUILD_TYPE="$DEFAULT_BUILD_TYPE"
DEBUGGER_TYPE="$DEFAULT_DEBUGGER_TYPE"

read_command_line_switches "$@"

if $CLEAN_SPECIFIED || $BUILD_SPECIFIED || $INSTALL_SPECIFIED || $PROGRAM_SPECIFIED || $DEBUG_SPECIFIED; then
  :
else
  abort "No operation requested."
fi

check_only_one "Only one build operation can be specified." $BUILD_SPECIFIED $INSTALL_SPECIFIED

JTAGDUE_ROOT_DIR="$(readlink -f "$PWD")"
PROJECT_SRC_DIR="$JTAGDUE_ROOT_DIR/Project"

case "${BUILD_TYPE}" in
  debug)   PROJECT_OBJ_DIR_SUFFIX="debug"   ;;
  release) PROJECT_OBJ_DIR_SUFFIX="release" ;;
  *) abort "Invalid build type of \"$BUILD_TYPE\"." ;;
esac


PROJECT_OBJ_DIR="$OUTPUT_DIR/JtagDue-obj-$PROJECT_OBJ_DIR_SUFFIX"
PROJECT_BIN_DIR="$OUTPUT_DIR/JtagDue-bin-$PROJECT_OBJ_DIR_SUFFIX"

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

# Convert to lowercase.
PROJECT_NAME="${PROJECT_NAME,,}"

case "${PROJECT_NAME}" in
  jtagdue)       BIN_FILENAME="JtagFirmware/jtagdue" ;;
  emptyfirmware) BIN_FILENAME="EmptyFirmware/emptydue" ;;
  *) abort "Invalid project name of \"$PROJECT_NAME\"." ;;
esac

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

if $PROGRAM_SPECIFIED || $DEBUG_SPECIFIED; then
  do_program_and_debug
fi

echo "All $SCRIPT_NAME operations done."

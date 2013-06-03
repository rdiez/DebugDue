#!/bin/bash

# This script generates files with random data in order to test if your JTAG interface
# can transfer large amounts of data reliably with OpenOCD.
#
# It also generates an OpenOCD TCL script and an alternative GDB script to transfer the data
# to and from the target. A final Bash script is generated in order to verify that
# the data received during the transfer test matches the data sent.
#
# This tool does not drive OpenOCD or GDB, as you probably need to provide target-specific arguments
# or perform target-specific configuration steps before you can start the data transfers.
# After the transfers are complete, you also need to manually run the generated
# data verification script with Bash.
#
# Script arguments:  <output directory name>  <start addr>  <byte count>  <random data test repeat count>  <memory type>
#
# Example:
#  ./GenerateDataTransferTest.sh "$HOME/data-files-dir" 0x20000000 65536 100 flash
#
# Choose the memory address and the byte count according to your target.
# The memory area  must be writeable memory and should not collide with the
# firmware running on the target.
#
# Note that 3 initial data sets are always generated, so the first random data test will be forth set generated.
#
# Make sure you have enough disk space for twice the amount of all the data to generate,
# as the data is read back and stored during the actual test.
#
# The test sequence is as follows:
#
# 1) Transfer a test data file full of zeros.
#    This should test the ability to delete old data.
#
# 2) Transfer a test data file full of binary ones (0xFFs).
#    Most flash memories start off with this content.
#
# 3) Transfer a test data file with a simple pattern.
#    If the JTAG connection is not reliable, one of the tests above
#    will probably make it fail. The test data is simple and easily reproducible.
#
# 4) Transfer as many test data sets as the user specified on the command line.
#
#
# Copyright (C) 2013 R. Diez
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Affero GNU General Public License version 3
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Affero GNU General Public License version 3 for more details.
#
# You should have received a copy of the Affero GNU General Public License version 3
# along with this program. If not, see http://www.gnu.org/licenses/ .


set -o errexit
set -o pipefail
set -o nounset
set -o posix

# set -x  # Enable tracing of this script.

abort ()
{
    echo >&2 && echo "Error in script \"$0\": $*" >&2
    exit 1
}


run_cmd ()
{
  printf "$1\n"
  eval "$1"
}


add_echo_line_to_scripts ()
{
  printf "echo \"$1\"\n" >>"$TCL_FILENAME"
  printf "echo \"$1\"\n" >>"$VERIFY_SCRIPT_FILENAME"

  printf "echo $1\\\n\n" >>"$GDB_FILENAME"
}


add_generated_file_to_scripts ()
{
  local FILENAME_TO_SEND="$1"
  local FILENAME_TO_RECEIVE="$2"

  case "$MEM_TYPE" in
    ram)    printf "load_image %s %s bin %s %s\n" "$FILENAME_TO_SEND" "$START_ADDR" "$START_ADDR" "$BYTE_COUNT" >>"$TCL_FILENAME";;
    flash)  printf "flash write_image erase unlock %s %s bin\n" "$FILENAME_TO_SEND" "$START_ADDR" >>"$TCL_FILENAME";;
    *)      abort "Invalid memory type \"$MEM_TYPE\".";;
  esac

  printf "dump_image %s %s %s\n\n" "$FILENAME_TO_RECEIVE" "$START_ADDR" "$BYTE_COUNT" >>"$TCL_FILENAME"

  printf "cmp \"%s\" \"%s\"\n" "$FILENAME_TO_SEND" "$FILENAME_TO_RECEIVE" >>"$VERIFY_SCRIPT_FILENAME"


  printf "restore %s binary %s 0 %s\n" "$FILENAME_TO_SEND" "$START_ADDR" "$(( $BYTE_COUNT ))" >>"$GDB_FILENAME"
  # Note that bash understands numbers in hex below if the have the '0x' prefix.
  printf "dump binary memory %s %s %s\n\n" "$FILENAME_TO_RECEIVE" "$START_ADDR" "$(( $START_ADDR + $BYTE_COUNT ))" >>"$GDB_FILENAME"
}


if (( $# != 5 ))
then
  abort "Invalid number of command-line arguments, see the script source code for help."
fi

DIRNAME="$(readlink -f "$1")"
START_ADDR="$2"
BYTE_COUNT="$3"
TEST_REPEAT_COUNT="$4"
MEM_TYPE="$5"

case "$MEM_TYPE" in
  ram)    ;;
  flash)  ;;
  *)      abort "Invalid memory type \"$MEM_TYPE\".";;
esac


if (( $TEST_REPEAT_COUNT < 1 ))
then
  abort "A random data test repeat count of \"$TEST_REPEAT_COUNT\" is invalid."
fi


DATA_TO_SEND="DataToSend"
DATA_RECEIVED="DataReceived"

DATA_TO_SEND_DIRNAME="$DIRNAME/$DATA_TO_SEND"
DATA_RECEIVED_DIRNAME="$DIRNAME/$DATA_RECEIVED"

SCRIPTS_DIRNAME="$DIRNAME/Scripts"

mkdir --parents "$DATA_TO_SEND_DIRNAME"
mkdir --parents "$SCRIPTS_DIRNAME"
mkdir --parents "$DIRNAME/$DATA_RECEIVED"

TCL_FILENAME="$SCRIPTS_DIRNAME/OpenOcdScript.tcl"
VERIFY_SCRIPT_FILENAME="$SCRIPTS_DIRNAME/VerifyReceivedData.sh"
GDB_FILENAME="$SCRIPTS_DIRNAME/GdbScript.txt"

printf "# This file was generated with script \"%s\".\n\n" "$0" >"$TCL_FILENAME"

printf "# This file was generated with script \"%s\".\n\n" "$0" >"$VERIFY_SCRIPT_FILENAME"
printf "set -o errexit\n\n" >>"$VERIFY_SCRIPT_FILENAME"
chmod a+x "$VERIFY_SCRIPT_FILENAME"

printf "# This file was generated with script \"%s\".\n\n" "$0" >"$GDB_FILENAME"

printf "Generating test data and transfer scripts...\n"


# Generate a file full of zeros. This file is also useful if the user wants to manually generate other files.

add_echo_line_to_scripts "Processing file full of zeros..."
ZEROS_FILENAME_TO_SEND="$DATA_TO_SEND_DIRNAME/$DATA_TO_SEND-zeros"
ZEROS_FILENAME_TO_RECEIVE="$DATA_RECEIVED_DIRNAME/$DATA_RECEIVED-zeros"
run_cmd "dd if=\"/dev/zero\" of=\"$ZEROS_FILENAME_TO_SEND\" bs=\"$BYTE_COUNT\" count=1 status=noxfer"
add_generated_file_to_scripts "$ZEROS_FILENAME_TO_SEND" "$ZEROS_FILENAME_TO_RECEIVE"


# Generate a file full of 0xFFs.

add_echo_line_to_scripts "Processing file full of 0xFFs..."
FFS_FILENAME_TO_SEND="$DATA_TO_SEND_DIRNAME/$DATA_TO_SEND-ffs"
FFS_FILENAME_TO_RECEIVE="$DATA_RECEIVED_DIRNAME/$DATA_RECEIVED-ffs"
run_cmd "sed -e\"s/\x00/\xff/g\" <\"$ZEROS_FILENAME_TO_SEND\" >\"$FFS_FILENAME_TO_SEND\""
add_generated_file_to_scripts "$FFS_FILENAME_TO_SEND" "$FFS_FILENAME_TO_RECEIVE"

# Generate a file with a single 16-byte pattern: 0x00, 0x01, 0x02, ... , 0x0F.

add_echo_line_to_scripts "Processing file with pattern 16..."
PATTERN_16_FILENAME_TO_SEND="$DATA_TO_SEND_DIRNAME/$DATA_TO_SEND-pattern16"
PATTERN_16_FILENAME_TO_RECEIVE="$DATA_RECEIVED_DIRNAME/$DATA_RECEIVED-pattern16"
PATTERN_16_FILENAME_TMP="$DATA_TO_SEND_DIRNAME/$DATA_TO_SEND-pattern16-tmp"

PATTERN_16_EXTRA_LEN="$(( $BYTE_COUNT + 16 - 1 ))"
run_cmd "dd if=\"/dev/zero\" of=\"$PATTERN_16_FILENAME_TMP\" bs=\"$PATTERN_16_EXTRA_LEN\" count=1 status=noxfer"
run_cmd "sed -e\"s/\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00/\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F/g\" <\"$PATTERN_16_FILENAME_TMP\" >\"$PATTERN_16_FILENAME_TO_SEND\""
run_cmd "truncate -s \"$BYTE_COUNT\" \"$PATTERN_16_FILENAME_TO_SEND\""
run_cmd "rm \"$PATTERN_16_FILENAME_TMP\""
add_generated_file_to_scripts "$PATTERN_16_FILENAME_TO_SEND" "$PATTERN_16_FILENAME_TO_RECEIVE"


# /dev/random is very slow and we don't need random data of very high quality.
RANDOM_DATA_SOURCE="/dev/urandom"

pushd "$DIRNAME" >/dev/null

for (( i=1; i<=$TEST_REPEAT_COUNT; i++ ))
do

  FILENAME_TO_SEND="$DATA_TO_SEND_DIRNAME/$DATA_TO_SEND-random-$i"
  FILENAME_TO_RECEIVE="$DATA_RECEIVED_DIRNAME/$DATA_RECEIVED-random-$i"

  run_cmd "dd if=\"$RANDOM_DATA_SOURCE\" of=\"$FILENAME_TO_SEND\" bs=\"$BYTE_COUNT\" count=1 status=noxfer"

  add_echo_line_to_scripts "Processing random test data file $i of $TEST_REPEAT_COUNT..."
  add_generated_file_to_scripts "$FILENAME_TO_SEND" "$FILENAME_TO_RECEIVE"

done

printf "echo \"Data verification successful.\"\n" >>"$VERIFY_SCRIPT_FILENAME"

popd >/dev/null

printf "\nDone.\n"
printf "Use the generated scripts in this directory to perform the tests:\n  %s\n" "$SCRIPTS_DIRNAME"


# Copyright (C) 2012-2014 R. Diez - see the JtagDue project for licensing information.

AC_INIT([arduino-due-native-usb-speed-test],[1.1.2])
AC_PREREQ([2.65])  # Tested mainly with version 2.69.

AC_NO_EXECUTABLES  # This undocumented hack prevents error message "error: C compiler cannot create executables",
                   # see the toolchain makefile for more information about why this is needed. Short version:
                   # libgloss was not adapted for our board, so the toolchain alone cannot build executables.

AM_INIT_AUTOMAKE([-Wall])

# Note that libtool (as of libtoolize 2.4.2) may generate spurious warning "configure: WARNING: using cross tools not prefixed with host triplet"
# if you have a tool called "mt" on your system (which probably gets installed with Ubuntu package 'cpio').
# I have reported this on the libtool mailing list:
#   Thread title: "configure: WARNING: using cross tools not prefixed with host triplet"
#   Thread URL:   http://lists.gnu.org/archive/html/libtool/2014-09/msg00008.html
LT_INIT

# Use "make V=1" (and remove the '-s' flag) in order to see the GCC command lines during compilation.
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

# According to the autoconf documentation, this is about the right place to define compiler flags:
#   If your package does not like this default, then it is acceptable to insert the line
#  ': ${CXXFLAGS=""}' after AC_INIT and before AC_PROG_CXX to select an empty default instead.
CXXFLAGS="-g -Wall"
CFLAGS="-g -Wall"
CCASFLAGS="-g -Wall"

AC_PROG_CC
AC_PROG_CXX
AM_PROG_AS
AC_PROG_INSTALL

AC_CONFIG_MACRO_DIR([m4])


# ----------- Check whether debug or release build -----------

AC_MSG_CHECKING(whether to generate a debug build)
AC_ARG_ENABLE([debug],
              [AS_HELP_STRING([--enable-debug=[[yes/no]]],
                              [generate a debug build with assertions and no optimization [default=no]])],
              [case "${enableval}" in
               yes) debug_build=true ;;
               no)  debug_build=false ;;
               *) AC_MSG_ERROR([bad value ${enableval} for --enable-debug]) ;;
               esac],
              debug_build=false)

if [ test x$debug_build = xtrue ]
then
    AC_MSG_RESULT(yes)
    # I had to add "-g" again at this point in order to get line number information generated
    # in the general debug information.
    # We could use GCC 4.8's new optimisation level "-Og", but "-O0" still provides the most comfortable debugging experience.
    # Switch -fmerge-constants helps mainly reduce the code size of all possible assertion failed messages.
    DEBUG_FLAGS="-O0 -fmerge-constants -DDEBUG -g3"
else
    AC_MSG_RESULT(no)
    # One quick test I did showed these JTAG transfer speeds: with -Os: 25 KB/s
    #                                                         with -O3: 35 KB/s
    # The firmware did get somewhat bigger with -O3 though.
    DEBUG_FLAGS="-O3 -DNDEBUG"
fi

CXXFLAGS+=" $DEBUG_FLAGS"
CFLAGS+=" $DEBUG_FLAGS"
CCASFLAGS+=" $DEBUG_FLAGS"


# ----------- Path to the Arduino environment -----------

# AC_ARG_WITH(arduino,
# [AS_HELP_STRING([--with-arduino=PATH],
# 		[specify directory for the installed Arduino package, for example "$HOME/arduino-1.5.2".])])
#
# if test "x$with_arduino" == x; then
#   AC_MSG_ERROR([Please specify the --with-arduino=PATH configuration switch])
# else
#   ARDUINO_ENV_BASEDIR="$(readlink -f "$with_arduino")"
# fi
#
#
# if ! test -d "${ARDUINO_ENV_BASEDIR}/hardware"; then
#   AC_MSG_ERROR([The Arduino package does not seem to be installed at $ARDUINO_ENV_BASEDIR])
# fi
#
# AC_SUBST(ARDUINO_ENV_BASEDIR)


# ----------- Path to the Atmel Software Framework -----------

AC_ARG_WITH(atmel-software-framework,
[AS_HELP_STRING([--with-atmel-software-framework=PATH],
		[specify directory for the installed Atmel Software Framework, for example "$HOME/asf-3.14.0.86".])])

if test "x$with_atmel_software_framework" == x; then
  AC_MSG_ERROR([Please specify the --with-atmel-software-framework=PATH configuration switch])
else
  ASF_BASEDIR="$(readlink -f "$with_atmel_software_framework")"
fi


if ! test -d "${ASF_BASEDIR}/sam"; then
  AC_MSG_ERROR([The Atmel Software Framework does not seem to be installed at $ASF_BASEDIR])
fi

AC_SUBST(ASF_BASEDIR)


# ----------------------------------------
# Add some extra compilation flags.

ARCH_FLAGS=" -mcpu=cortex-m3 -mthumb"  # Switch "-march=armv7-m" could also be an option.

EXTRA_C_AND_CXX_FLAGS=""

# WARNING: All flags that affect the ABI must match those specified when building the toolchain.

EXTRA_C_AND_CXX_FLAGS+=" -ffunction-sections -fdata-sections"

# I am not sure whether specifying our own --param max-inline-insns-single is a good idea,
# but that's what the Arduino Framework does:
EXTRA_C_AND_CXX_FLAGS+=" --param max-inline-insns-single=500"

EXTRA_CPP_FLAGS=""

EXTRA_CPP_FLAGS+=" -DBOARD=ARDUINO_DUE_X"

EXTRA_CPP_FLAGS+=" -D_GNU_SOURCE"  # This select the right version of strerror_r().

# Needed for both CMSIS and the lib under "arduino-1.5.2/hardware/arduino/sam/cores".
EXTRA_CPP_FLAGS+=" -D__SAM3X8E__"

# Needed by the Atmel Software Framework.
EXTRA_CPP_FLAGS+=" -DSAM3XA_SERIES"

# Needed by NewlibSyscalls.cpp.
EXTRA_CPP_FLAGS+=" -DASSERT_MSG_BUFSIZE=300"

# Needed by the Atmel Software Framework.
EXTRA_CPP_FLAGS+=" -DCPU_CLOCK=84000000"

# I had problems building some files in the Atmel Software Framework version 3.7.3.69
# when I defined this flag:
#   EXTRA_CPP_FLAGS+=" -DUDD_NO_SLEEP_MGR"

# USB Vendor and Device ID definitions for the 'native' USB port.
#
# The standard Arduino firmware uses ID 0x003e in a composite device
# configuration, which means that the Windows .INF driver uses the following string:
#   USB\VID_2341&PID_003E&MI_00
# Note the "MI_00" at the end that denotes the interface number on the composite device.
#
# Linux needs no drivers, all CDC interfaces are automatically recognised.
# I have heard that composite devices are not supported on Mac OS, but I don't really know.
#
# The JtagDue Firmware does not use a composite device, but defines a single CDC device,
# so that the standard Arduino Due INF driver does not work even if you use the same PID.
#
# Therefore, I have chosen a different PID of 0x1234. You can choose your own,
# but then you will need to modify the .INF driver file and reinstall it on Windows.

EXTRA_CPP_FLAGS+=" -DUSB_VID=0x2341 -DUSB_PID=0x1234"


# Assorted extra warnings.
EXTRA_C_AND_CXX_FLAGS+=" -fdiagnostics-show-option"
EXTRA_C_AND_CXX_FLAGS+=" -Wall -Wextra"
EXTRA_C_AND_CXX_FLAGS+=" -Wshadow -Wpointer-arith -Wcast-qual"
EXTRA_C_AND_CXX_FLAGS+=" -Wunreachable-code"
EXTRA_C_AND_CXX_FLAGS+=" -Wredundant-decls"
EXTRA_C_AND_CXX_FLAGS+=" -Wwrite-strings"
EXTRA_C_AND_CXX_FLAGS+=" -Wfloat-equal"
EXTRA_C_AND_CXX_FLAGS+=" -Wformat=2"
EXTRA_C_AND_CXX_FLAGS+=" -Wunknown-pragmas"
EXTRA_C_AND_CXX_FLAGS+=" -Wattributes"
EXTRA_C_AND_CXX_FLAGS+=" -Wtrampolines"
EXTRA_C_AND_CXX_FLAGS+=" -Wnormalized=nfc"
EXTRA_C_AND_CXX_FLAGS+=" -Wpragmas"
EXTRA_C_AND_CXX_FLAGS+=" -Wlogical-op"
EXTRA_C_AND_CXX_FLAGS+=" -Wunsafe-loop-optimizations"
EXTRA_C_AND_CXX_FLAGS+=" -Wstack-protector"
EXTRA_C_AND_CXX_FLAGS+=" -Wbuiltin-macro-redefined"
# EXTRA_C_AND_CXX_FLAGS+=" -Wmudflap"  # Not available from GCC version 4.9.
EXTRA_C_AND_CXX_FLAGS+=" -Wabi"
EXTRA_C_AND_CXX_FLAGS+=" -Wcpp"
EXTRA_C_AND_CXX_FLAGS+=" -Wendif-labels"
EXTRA_C_AND_CXX_FLAGS+=" -Wdeprecated"
EXTRA_C_AND_CXX_FLAGS+=" -Wdeprecated-declarations"
EXTRA_C_AND_CXX_FLAGS+=" -Wdiv-by-zero"
EXTRA_C_AND_CXX_FLAGS+=" -Wdouble-promotion"

EXTRA_C_FLAGS=""
EXTRA_C_FLAGS+=" -Wc++-compat"
EXTRA_C_FLAGS+=" -Wstrict-prototypes"
EXTRA_C_FLAGS+=" -Wmissing-prototypes"
EXTRA_C_FLAGS+=" -Wpointer-to-int-cast"


# Turn off warnings that occur too often in the libraries.
EXTRA_C_AND_CXX_FLAGS+=" -Wno-missing-field-initializers"

EXTRA_C_AND_CXX_FLAGS+=" -Wno-psabi"  # Suppresses warning "the mangling of 'va_list' has changed in GCC 4.4".
                                      # I do not know yet if this warning should be taken seriously.


# ---  Include paths.

# libsam

EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/drivers/pmc"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/drivers/pio"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/drivers/rstc"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/drivers/wdt"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/drivers/adc"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/drivers/uart"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/utils"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/utils/header_files"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/utils/preprocessor"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/sam/boards"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/common/utils"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/common/services/clock"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/common/boards"

# CMSIS

CMSIS_BASE_DIR="$ASF_BASEDIR/sam/utils/cmsis/sam3x"

CMSIS_SRC_TEMPLATE_DIR="$CMSIS_BASE_DIR/source/templates"
AC_SUBST(CMSIS_SRC_TEMPLATE_DIR)

EXTRA_CPP_FLAGS+=" -I$CMSIS_BASE_DIR/include"
EXTRA_CPP_FLAGS+=" -I$CMSIS_SRC_TEMPLATE_DIR"
EXTRA_CPP_FLAGS+=" -I$ASF_BASEDIR/thirdparty/CMSIS/Include"

# --- Set the final variables.

CXXFLAGS+=" $ARCH_FLAGS $EXTRA_C_AND_CXX_FLAGS"
CFLAGS+=" $ARCH_FLAGS $EXTRA_C_AND_CXX_FLAGS $EXTRA_C_FLAGS"
CCASFLAGS+=" $ARCH_FLAGS"

CPPFLAGS+=" $EXTRA_CPP_FLAGS"

# ----------------------------------------

BARE_METAL_SUPPORT_DIR="$(readlink -f "$srcdir/BareMetalSupport")"
AC_SUBST(BARE_METAL_SUPPORT_DIR)

# If you update this line, please update SUBDIRS in Makefile.am too.
AC_CONFIG_FILES([Makefile BareMetalSupport/Makefile JtagFirmware/Makefile EmptyFirmware/Makefile])

AC_OUTPUT

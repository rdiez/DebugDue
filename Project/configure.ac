
# Copyright (C) 2012-2017 R. Diez - see the JtagDue project for licensing information.

# By default, if you change the firmware version number below, the next 'make' invocation
# will rebuild the 'configure' script. This script will have the updated version number
# in the PACKAGE_VERSION variable. All makefiles will automatically get rebuilt,
# but despite this, the sources will not be recompiled.
# I tried the "maintainer mode" (AM_MAINTAINER_MODE), but that did not help.
AC_INIT([JtagDue],[1.1.4])
AC_PREREQ([2.65])  # Tested mainly with version 2.69.

AC_NO_EXECUTABLES  # This undocumented hack prevents error message "error: C compiler cannot create executables",
                   # see the toolchain makefile for more information about why this is needed. Short version:
                   # libgloss was not adapted for our board, so the toolchain alone cannot build executables.

AM_INIT_AUTOMAKE([-Wall])


if ! test set = "${BASH_VERSION+set}"; then
  # How to test this error path:
  #    CONFIG_SHELL=/bin/sh ./configure
  # The following will not work, as the generated 'configure' script seems to change the shell automatically:
  #   /bin/sh ./configure
  AC_MSG_ERROR([Please run this 'configure' script with Bash, as it uses Bash-only features, and has only been tested against Bash. Start it like this: CONFIG_SHELL=/bin/bash ./configure])
fi


# Use "make V=1" (and remove the '-s' flag) in order to see the GCC command lines during compilation.
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

# According to the autoconf documentation, this is about the right place to define compiler flags:
#
#   If your package does not like this default, then it is acceptable to insert the line
#  ': ${CXXFLAGS=""}' after AC_INIT and before AC_PROG_CXX to select an empty default instead.
#
# We are clearing these variables here because they are actually user variables and we want to reserve
# them for the end user, so that he can add his own flags when invoking the generated makefiles.
# Instead, we will be overriding AM_CFLAGS and friends below.
#
# The user will normally not modify important flags, but some of them, like "-fdiagnostics-color=always",
# depend on factors outside of our control and should not be set by this configuration script.

declare -a USER_VARIABLES=(CXXFLAGS CFLAGS CCASFLAGS LDFLAGS)

for varName in "${USER_VARIABLES[[@]]}"  # Note that autoconf needs to escape brackets ('[[' instead of '[').
do                                       # Alternatively, you can use trigraphs @<:@ and @>:@ .
  eval "$varName=\"\""
done

AC_PROG_CC
AC_PROG_CXX
AM_PROG_AS
AC_PROG_INSTALL

AM_EXTRA_RECURSIVE_TARGETS([disassemble])


# ----------- Check GCC version number -----------

if test "x$GCC" != "xyes"; then
  AC_MSG_ERROR([GCC is the only supported compiler at the moment.])
fi

AX_COMPILER_VERSION

# For some reason, variable ax_cv_cxx_compiler_version for the C++ compiler version
# does not work for me.
if false; then
  if test "x$ax_cv_c_compiler_version" != "x$ax_cv_cxx_compiler_version"; then
    AC_MSG_ERROR([The gcc and g++ versions do not match.])
  fi
fi

IS_GCC_7_OR_LATER=false
AS_VERSION_COMPARE( [$ax_cv_c_compiler_version], [7], [], [], [IS_GCC_7_OR_LATER=true] )


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
    BUILD_FLAGS="-O0 -fmerge-constants -DDEBUG -g3"
    IS_DEBUG_BUILD=true
else
    AC_MSG_RESULT(no)
    # One quick test I did showed these JTAG transfer speeds: with -Os: 25 KB/s
    #                                                         with -O3: 35 KB/s
    # The firmware did get somewhat bigger with -O3 though.
    # It would probably be best to compile with -Os by default and mark some modules or functions for
    # -O3 optimisation with GCC options "#pragma GCC optimize ("string"...)" and "attribute((optimize("STRING")))".
    BUILD_FLAGS="-O3 -DNDEBUG -g3"

    if true; then
      # The GCC toolchain is built with --enable-lto. I hope that makes it build the C runtime library,
      # libstdc++, etc. with -flto. We should probably build newlib with LTO enabled too.
      BUILD_FLAGS+=" -flto"
    fi

    IS_DEBUG_BUILD=false
fi

BUILD_FLAGS+=" -Wall"


# ----------- Path to the Atmel Software Framework -----------

AC_ARG_WITH(atmel-software-framework,
[AS_HELP_STRING([--with-atmel-software-framework=PATH],
		[specify directory for the installed Atmel Software Framework, for example "$HOME/asf-3.14.0.86".])])

if test "x$with_atmel_software_framework" == x; then
  AC_MSG_ERROR([Please specify the --with-atmel-software-framework=PATH configuration switch])
fi

ASF_BASEDIR="$(readlink --verbose --canonicalize -- "$with_atmel_software_framework")"
SAM_DIR="$ASF_BASEDIR/sam"

if ! test -d "$SAM_DIR"; then
  # If the path is completely wrong, 'readlink' can fail. Therefore, we must not use its result in the error message.
  AC_MSG_ERROR([The Atmel Software Framework does not seem to be installed at "$with_atmel_software_framework" (directory "$SAM_DIR" not found).])
fi

# Create or update the symbolic link to the ASF.
# Using a symbolic link is the only way I found that works well with Automake's option 'subdir-objects'.
# Otherwise, trying to compile files that live out of the source tree will give you strange warnings at the very least.
ASF_LINK="$srcdir/AsfSrc"
ln --symbolic --no-dereference --force -- "$ASF_BASEDIR" "$ASF_LINK"


# ----------- target arch -----------

# I have not figured out yet how to get the value passed as --host,
# so I am passing it again in a separate command-line option.

AC_ARG_WITH(target-arch,
[AS_HELP_STRING([--with-target-arch=arch],
		[specify the same architecture as argument -host.])])

if test "x$with_target_arch" == x; then
  AC_MSG_ERROR([Please specify the --with-target-arch=arch configuration switch.])
fi

TARGET_ARCH="$with_target_arch"
AC_SUBST(TARGET_ARCH)


# ----------- project name -----------

AC_ARG_WITH(project,
[AS_HELP_STRING([--with-project=project-name],
		[specify 'JtagDue' or 'EmptyFirmware'.])])

if test "x$with_project" == x; then
  AC_MSG_ERROR([Please specify the --with-project=project-name configuration switch.])
fi

PROJECT_NAME_LOWERCASE="${with_project,,}"

IS_EMPTY_FIRMWARE=false
IS_JTAG_DUE=false

case "$PROJECT_NAME_LOWERCASE" in
  jtagdue)       IS_JTAG_DUE=true ;;
  emptyfirmware) IS_EMPTY_FIRMWARE=true ;;
  *) AC_MSG_ERROR([Invalid project name of "$with_project".]) ;;
esac

AM_CONDITIONAL([IS_EMPTY_FIRMWARE], [test $IS_EMPTY_FIRMWARE = true])
AM_CONDITIONAL([IS_JTAG_DUE], [test $IS_JTAG_DUE = true])


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

# Needed by the Atmel Software Framework library.
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

if $IS_GCC_7_OR_LATER; then
  # This warning is new in GCC 7. Atmel's ASF library versions 3.34.2.53 and the latest 3.40.0 generate many of these.
  EXTRA_C_AND_CXX_FLAGS+=" -Wno-expansion-to-defined"
fi

EXTRA_C_FLAGS=""
EXTRA_C_FLAGS+=" -Wc++-compat"
EXTRA_C_FLAGS+=" -Wstrict-prototypes"
EXTRA_C_FLAGS+=" -Wmissing-prototypes"
EXTRA_C_FLAGS+=" -Wpointer-to-int-cast"

EXTRA_C_FLAGS+=" -std=gnu11"
# With -std=c++11 you do not get vsnprintf.
EXTRA_CXX_FLAGS=" -std=gnu++14"

# Turn off warnings that occur too often in the libraries.
EXTRA_C_AND_CXX_FLAGS+=" -Wno-missing-field-initializers"

EXTRA_C_AND_CXX_FLAGS+=" -Wno-psabi"  # Suppresses warning "the mangling of 'va_list' has changed in GCC 4.4".
                                      # I do not know yet if this warning should be taken seriously.

# This GCC option apparently does not work with LTO, at least with GCC 4.9.3:
#   #pragma GCC diagnostic ignored "-Wframe-larger-than="
# Therefore, enable this warning only in Debug-Builds:
if $IS_DEBUG_BUILD; then
  EXTRA_C_AND_CXX_FLAGS+=" -Wframe-larger-than=400"  # This limit of 400 bytes is rather arbitrary. But it helps.
  # Option -Wstack-usage is better, as it considers things like alloca() and variable-length arrays.
  # However, you then get the occasional warning "stack usage computation not supported for this target",
  # at least when using inline assembly.
fi


# --- Set the final variables.

AM_CPPFLAGS=" $EXTRA_CPP_FLAGS"
AM_CFLAGS=" $BUILD_FLAGS $ARCH_FLAGS $EXTRA_C_AND_CXX_FLAGS $EXTRA_C_FLAGS"
AM_CXXFLAGS=" $BUILD_FLAGS $ARCH_FLAGS $EXTRA_C_AND_CXX_FLAGS $EXTRA_CXX_FLAGS"
AM_CCASFLAGS=" $BUILD_FLAGS $ARCH_FLAGS"

AC_SUBST(AM_CPPFLAGS)
AC_SUBST(AM_CFLAGS)
AC_SUBST(AM_CXXFLAGS)
AC_SUBST(AM_CCASFLAGS)

# ----------------------------------------

AM_CONDITIONAL([USE_GOLD_LINKER], [false])

ABS_SRCDIR="$(readlink --verbose --canonicalize -- "$srcdir")"

BARE_METAL_SUPPORT_DIR="$ABS_SRCDIR/BareMetalSupport"
AC_SUBST(BARE_METAL_SUPPORT_DIR)

# If you update this line, please update SUBDIRS in Makefile.am too.
#
# I have not found a way to pass a variable to AC_CONFIG_FILES, as AC_CONFIG_FILES simply will not expand a shell variable.
# Therefore, all possible makefiles are listed here, even if not all of them are compiled later (see Makefile.am).
# As a potential work-around, autogen.sh could generate an .m4 file with the right (shorter) list, which would then be included here.
AC_CONFIG_FILES(
  Makefile
)

AC_OUTPUT


SHOW_AUTOTOOLS_VERSIONS=false

if $SHOW_AUTOTOOLS_VERSIONS; then
  echo "Autotools versions:"

  TMP_TXT="$(autoconf --version)"
  head -n 1 - <<<"- $TMP_TXT"

  TMP_TXT="$(automake --version)"
  head -n 1 - <<<"- $TMP_TXT"
fi


# Check that we did actually leave user variables to the end user.
for varName in "${USER_VARIABLES[[@]]}"; do
  if [[ ! -z "${!varName}" ]]; then
    AC_MSG_ERROR([Variable $varName should be undefined or empty, because it is reserved for the end user. However, $varName has the following value: ${!varName}])
  fi
done

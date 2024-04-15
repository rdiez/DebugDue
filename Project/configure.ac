
# Copyright (C) 2012-2021 R. Diez - see the DebugDue project for licensing information.

# By default, if you change the firmware version number below, the next 'make' invocation
# will rebuild the 'configure' script. This script will have the updated version number
# in the PACKAGE_VERSION variable. All makefiles will automatically get rebuilt,
# but despite this, the sources will not be recompiled.
# I tried the "maintainer mode" (AM_MAINTAINER_MODE), but that did not help.
AC_INIT([DebugDue],[1.1.7])
AC_PREREQ([2.69])  # Anything older may not work properly.

# Place auxiliary files in a subdirectory in order to reduce clutter in the top-level project directory.
# This also prevents the configuration script from looking for helper scripts outside this project,
# in ../ and ../../ , possibly finding older versions or incompatible tools with the same name.
AC_CONFIG_AUX_DIR([build-aux])

AC_NO_EXECUTABLES  # This undocumented macro prevents error message "error: C compiler cannot create executables".
                   # We are using a custom cross-compiler toolchain which cannot build normal executables by default.
                   # We will be providing the right start-up routines and the right compiler flags when building
                   # our firmware, but the 'configure' script that Autoconf generates wants to probe
                   # the compiler etc. beforehand, so tell it that it cannot expect to build executables successfully.

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
# We are clearing CXXFLAGS etc. below here because they are actually meant to be user variables, so
# we want to reserve them for the end user. This way, he/she can add his/her own flags
# when using the generated makefiles.
#
# That is, we do not want to pick those values up from the environment when the project is configured.
# The user may specify them later on like this:
#   make  CXXFLAGS=my_values  my_target
#
# This script clears those variables and checks at the end that they have not been set.
# With this strategy, it is clear that any value in CXXFLAGS etc. come from the end user.
#
# This is a decision I have made which may prove wrong in the future. If you know better, drop me a line.
#
# Instead of playing with CXXFLAGS etc., we will be overriding AM_CFLAGS and friends below.
#
# The user will normally not modify important flags, but some of them, like "-fdiagnostics-color=always",
# depend on factors outside of our control and should not be set by this configuration script.
#
# In any case, keep in mind that this script could build in the future both binaries for the target
# and for the host (like some build tool). Therefore, you probably want to differentiate between CFLAGS
# for the host and for the target. For example, Newlib uses separate variable CFLAGS_FOR_TARGET.

declare -a USER_VARIABLES=(CPPFLAGS CFLAGS CXXFLAGS CCASFLAGS LDFLAGS)

for varName in "${USER_VARIABLES[[@]]}"  # Note that autoconf needs to escape brackets ('[[' instead of '[').
do                                       # Alternatively, you can use trigraphs @<:@ and @>:@ .
  eval "$varName=\"\""
done

AC_PROG_CC
AC_PROG_CXX
AM_PROG_AS
AC_PROG_RANLIB

# Whether macro AC_PROG_INSTALL is present makes no difference: the generated 'configure' script still looks
# for a "BSD-compatible install" program, and variable INSTALL is still set accordingly.
AC_PROG_INSTALL

AM_EXTRA_RECURSIVE_TARGETS([disassemble])


ABS_SRCDIR_SRC="$(readlink --verbose --canonicalize -- "$srcdir/src")"


AppendIncludeOrSystemIncludeDir ()
{
  local VARIABLE_NAME="$1"
  local INCLUDE_PATH="$2"
  local INCLUDE_FLAG="$3"

  # It is not really necessary to check whether the directory exists,
  # but it helps catch problems in the build system.

  if ! [[ -d "$INCLUDE_PATH" ]]; then
    AC_MSG_ERROR([Include directory "$2" does not exist.])
  fi

  printf -v "$VARIABLE_NAME" \
         "%s %q %q" \
         "${!VARIABLE_NAME}" \
         "$INCLUDE_FLAG" \
         "$INCLUDE_PATH"
}

AppendIncludeDir ()
{
  AppendIncludeOrSystemIncludeDir "$1" "$2" "-I"
}

# Option -isystem turns off compilation warnings for the related include files.
# That often makes sense for libraries that we cannot fix ourselves.
AppendSystemIncludeDir ()
{
  AppendIncludeOrSystemIncludeDir "$1" "$2" "-isystem"
}


# Say you have a shell variable called 'MY_OPTION' with value 'true'.
# This routine will add a '-DMY_OPTION=1' command-line argument to shell variable EXTRA_CPP_FLAGS,
# intended for the C/C++ preprocessor.

PublishBooleanVariableAsCPreprocessorSymbol ()
{
  local VARIABLE_NAME="$1"

  if false; then
    echo "Setting boolean C preprocessor symbol: <${VARIABLE_NAME}>, value: <${!VARIABLE_NAME}>"
  fi

  if [[ -z "${!VARIABLE_NAME+x}" ]]; then
    AC_MSG_ERROR([There is no shell variable named "$1".])
  fi

  if ! [[[ ${!VARIABLE_NAME} = "true" || ${!VARIABLE_NAME} = "false" ]]]; then
    AC_MSG_ERROR([Shell variable "$VARIABLE_NAME" should be boolean but has invalid value "${!VARIABLE_NAME}".])
  fi

  if [[ -z "${EXTRA_CPP_FLAGS+x}" ]]; then
    AC_MSG_ERROR([Shell variable EXTRA_CPP_FLAGS is not defined yet when attempting to add boolean C preprocessor symbol "VARIABLE_NAME".])
  fi

  if ${!VARIABLE_NAME}; then
    EXTRA_CPP_FLAGS+=" -D${VARIABLE_NAME}=1"
  else
    EXTRA_CPP_FLAGS+=" -D${VARIABLE_NAME}=0"
  fi
}


# Say you have a shell variable called 'MY_OPTION' with value 'true'. This M4 macro
# will make 'MY_OPTION' available in configure.ac and in the C/C++ source code.
#
# This is an M4 macro, and not a shell function, because it is hard to call M4 macros
# like AM_SUBST with shell variables as arguments.

AC_DEFUN([PUBLISH_BOOLEAN_VARIABLE],
         [
           if false; then
             echo "Publishing boolean variable: <$1>, value: <$$1>."
           fi

           # We could optimise the checks below away, because PublishBooleanVariableAsCPreprocessorSymbol does similar checks,
           # but I would rather keep the checks here, if only for example purposes.
           if [[ -z "${$1+x}" ]]; then
             AC_MSG_ERROR([There is no shell variable named "$1".])
           fi

           if ! [[[ $$1 = "true" || $$1 = "false" ]]]; then
             AC_MSG_ERROR([Shell variable "$1" should be boolean but has invalid value "$$1".])
           fi

           # A boolean variable is normally not used in all of the ways below, but always 'publishing'
           # in all ways makes the configure.ac script simpler an easier to maintain.

           # AM_CONDITIONAL allows you to use the variable in "if VARIABLE" statements inside the Makefile.am file.
           AM_CONDITIONAL([$1],[$$1])

           # AC_SUBST allows you to use the variable in expressions like $(VARIABLE) and @VARIABLE@ inside the Makefile.am file.
           # This is apparently called "configure substitution" in Automake.
           AC_SUBST([$1])

           # Adding -DVARIABLE=0/1 to the compiler flags makes the variable available in the C/C++ source code as a preprocessor symbol.
           PublishBooleanVariableAsCPreprocessorSymbol "$1"
         ]
        )


# ----------- Check GCC version number -----------

if test "x$GCC" != "xyes"; then
  AC_MSG_ERROR([GCC is the only supported compiler at the moment.])
fi

# This code is inspired by macro AX_COMPILER_VERSION. Actually using that macro would
# force the user to install the GNU Autoconf Archive beforehand.
# Note that we are assuming here that the C and C++ compilers are the same version.
AC_COMPUTE_INT(gcc_version_major, __GNUC__,, AC_MSG_FAILURE([unknown gcc major]))
AC_COMPUTE_INT(gcc_version_minor, __GNUC_MINOR__,, AC_MSG_FAILURE([unknown gcc minor]))
AC_COMPUTE_INT(gcc_version_patch, __GNUC_PATCHLEVEL__,, AC_MSG_FAILURE([unknown gcc patch level]))
my_compiler_version="$gcc_version_major.$gcc_version_minor.$gcc_version_patch"
echo "Detected compiler: GCC $my_compiler_version"

# This check is not really necessary, as we only support GCC version 10 or later,
# but this kind of version check will probably be useful in the future again,
# so I have kept the code here.
if false; then
  IS_GCC_10_OR_LATER=false
  AS_VERSION_COMPARE( [$my_compiler_version], [10], [], [], [IS_GCC_10_OR_LATER=true] )
fi


# ----------- Flag variables -----------

BUILD_FLAGS=""           # Flags for C, C++ and the assembler.
EXTRA_CPP_FLAGS=""       # C and C++ preprocessor flags.
EXTRA_C_FLAGS=""         # C flags.
EXTRA_CXX_FLAGS=""       # C++ flags.
EXTRA_C_AND_CXX_FLAGS="" # Flags for both C and C++.
EXTRA_LD_FLAGS=""        # Flags for the linker.


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
    # We could use GCC 4.8's new optimisation level "-Og", but "-O0" still provides the most comfortable debugging experience.
    # Switch -fmerge-constants helps mainly reduce the code size of all possible assertion failed messages.
    BUILD_FLAGS+=" -O0 -fmerge-constants -DDEBUG"
    IS_DEBUG_BUILD=true
else
    AC_MSG_RESULT(no)
    # One quick test I did showed these JTAG transfer speeds: with -Os: 25 KB/s
    #                                                         with -O3: 35 KB/s
    # The firmware did get somewhat bigger with -O3 though.
    # It would probably be best to compile with -Os by default and mark some modules or functions for
    # -O3 optimisation with GCC options "#pragma GCC optimize ("string"...)" and "attribute((optimize("STRING")))".
    BUILD_FLAGS+=" -O3 -DNDEBUG"

    declare -r ENABLE_LTO=true

    if $ENABLE_LTO; then

      # Notes about option "-flto=auto":
      # - Setting "auto" is only available on GCC version 10 and later.
      #   If you using an older GCC version, use "-flto" or "-flto=n",
      #   because "-flto=jobserver" is unlikely to work.
      #   But beware that this project only supports GCC version 10 or later.
      # - GCC only uses the inherited jobserver under certain situations.
      #   If GCC ends up not using it, and you are using a top-level jobserver to build several
      #   projects like this one in parallel, then LTO could overload the system,
      #   as there will be no global limit to the number of parallel jobs.
      # - Only GNU Make version 4.4 and later supports named pipes in the jobserver,
      #   and only on some platforms.
      # - If GNU Make uses inherited file descriptors, the jobserver will not be used.
      #   The make recipes must start with the special character '+' in order for GNU Make to pass
      #   the jobserver file descriptors to the child processes. Unfortunately, that is not possible
      #   with Automake 1.15.1 and later versions (as of 1.16.5). I asked in the Automake mailing list to no avail:
      #     Subject: Prepending '+' to the recipe line when linking with GCC's -flto=jobserver
      #     URL: https://lists.gnu.org/archive/html/automake/2020-02/msg00012.html
      # - Only GCC version 13 and later support named pipes in the jobserver.
      #
      # In short: Using "-flto=auto" should parallelise LTO, but an inherited jobserver
      # (supposed to limit the system load) may not be honoured.
      BUILD_FLAGS+=" -flto=auto"

      # Compilation is faster without "fat LTO objects", and the .o files are also significantly smaller.
      # The following option is not really necessary, because that mode is actually the default in our toolchain,
      # but the option and this comment acts as a reminder, so that I do not have to think about it again.
      # Note that you cannot perform a regular, non-LTO link with non-fat object files.
      BUILD_FLAGS+=" -fno-fat-lto-objects"
    fi

    IS_DEBUG_BUILD=false
fi


# Generate debugging information.
#
# Level 3 makes debugging information include extra data like preprocessor macro definitions (#define symbols).
# Therefore, I would normally use -g3 . Unfortunately, GDB 10.1 exhibits a very high CPU load and
# extreme memory consumption on programs built with -g3 , especially when building with LTO,
# at least when cross-compiling for ARM Cortex-M3 with GCC 10.3 . See this bug report for more details:
#   https://sourceware.org/bugzilla/show_bug.cgi?id=27754
#
# I have also noticed in the past that including preprocessor macro definitions with -g3
# does not really work with LTO builds, at least with GCC version 8.3.0 . So this area seems problematic.

BUILD_FLAGS+=" -g2"

BUILD_FLAGS+=" -fno-common"  # Should be the default, but just in case.


# ----------- Project Name -----------

AC_ARG_WITH(project,
[AS_HELP_STRING([--with-project=project-name],
                [see the --project option in the top-level build script.])])

if test "x$with_project" == x; then
  AC_MSG_ERROR([Please specify the --with-project=project-name configuration switch.])
fi

PROJECT_NAME_LOWERCASE="${with_project,,}"

IS_EMPTY_FIRMWARE=false
IS_QEMU_FIRMWARE=false
IS_DEBUG_DUE=false
NEEDS_ATMEL_SOFTWARE_FRAMEWORK=false
ASF_INCLUDE_COMMON=""
NEEDS_BARE_METAL=false

case "$PROJECT_NAME_LOWERCASE" in
  emptyfirmware) IS_EMPTY_FIRMWARE=true
                 BOARD_SUPPORT_DIR="BoardSupport-ArduinoDue"
                 NEEDS_BARE_METAL=true
                 NEEDS_ATMEL_SOFTWARE_FRAMEWORK=true
                 AppendIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/EmptyFirmware/ConfigFilesForAsf"
                 ;;
  qemufirmware)  IS_QEMU_FIRMWARE=true
                 BOARD_SUPPORT_DIR="BoardSupport-LM3S6965EVB"
                 ;;
  debugdue)      IS_DEBUG_DUE=true
                 BOARD_SUPPORT_DIR="BoardSupport-ArduinoDue"
                 NEEDS_BARE_METAL=true
                 NEEDS_ATMEL_SOFTWARE_FRAMEWORK=true
                 AppendIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/JtagFirmware/ConfigFilesForAsf"
                 AppendIncludeDir EXTRA_CPP_FLAGS "$srcdir/src/JtagFirmware"
                 ;;

  *) AC_MSG_ERROR([Invalid project name "$with_project".]) ;;
esac

# BOARD_SUPPORT_DIR must not be an absolute path, or Automake will litter
# that directory with object files.
AC_SUBST(BOARD_SUPPORT_DIR)


BARE_METAL_SUPPORT_DIR="$ABS_SRCDIR_SRC/BareMetalSupport"
AC_SUBST(BARE_METAL_SUPPORT_DIR)

# This is so that including a file with a relative path like <Misc/AssertionUtils.h> works.
AppendIncludeDir EXTRA_CPP_FLAGS "$srcdir/src"


# ----------- Path to the Atmel Software Framework -----------

AC_ARG_WITH(atmel-software-framework,
[AS_HELP_STRING([--with-atmel-software-framework=PATH],
                [specify directory for the installed Atmel Software Framework, for example "$HOME/asf-3.14.0.86".])])

if $NEEDS_ATMEL_SOFTWARE_FRAMEWORK; then

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
  # Later note: This might have been fixed in Automake version 1.16.
  ASF_LINK="$srcdir/src/AsfSrc"
  ln --symbolic --no-dereference --force -- "$ASF_BASEDIR" "$ASF_LINK"

fi


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

if false; then
  # We could make GCC use pipes instead of temporary files, probably speeding up builds by some small amount.
  # Using pipes should run compilation stages in parallel, which may help in some cases.
  # It also tends to use more RAM, because more processes run in parallel.
  # Some people report issues with this flag though, probably because it is not very widely used and tested.
  # This option is not compatible with -save-temps, see warning "-pipe ignored because -save-temps specified".
  EXTRA_C_AND_CXX_FLAGS+=" -pipe"
fi

# WARNING: All flags that affect the ABI must match those specified when building the toolchain.

BUILD_FLAGS+=" -mcpu=cortex-m3 -mthumb"  # Switch "-march=armv7-m" could also be an option.

EXTRA_C_AND_CXX_FLAGS+=" -ffunction-sections -fdata-sections"

# With -fuse-cxa-atexit, which tends to be the default (see config option --enable-__cxa_atexit),
# GCC will register the destructors of static objects dynamically with __cxa_atexit, which is a kind of atexit().
# Depending on the size of your application and on your libc configuration, those registrations will either
# consume extra RAM, or only the first 32 registrations will succeeded, and the rest will be discarded.
# See _ATEXIT_SIZE 32 for ANSI conformance.
# Assuming that you do not hit an eventual discard limit, this makes the destructions of static C++ objects
# conform to the C++ standard. The main aspect here is the order of destruction, but the whole construction order
# of static C++ objects is problematic anyway, so it is best to avoid code that depends on the correct order.
# With -fno-use-cxa-atexit, all such destructors are preregistered in the fini array and will not consume RAM,
# only program memory (ROM or Flash memory). However, the destruction order is not guaranteed
# to be correct according to the C++ standard.
# Alternatively, if your firmware never exits, you may use something like _LITE_EXIT and drop all destruction.
# But it is always a good idea to provide a termination path, even if only manually triggered for debug purposes.
# Code that properly terminates can be migrated later on to other platforms that do terminate.
# And having a proper termination path makes it easier to detect and analyse memory leaks.
EXTRA_CXX_FLAGS+=" -fno-use-cxa-atexit"

# These flags may save a little program space:
if false; then

  EXTRA_CXX_FLAGS+=" -fno-use-cxa-get-exception-ptr"  # Don't use the __cxa_get_exception_ptr runtime routine. This causes std::uncaught_exception
                                                      # to be incorrect, but is necessary if the runtime routine is not available.
                                                      # Note that std::uncaught_exception was deprecated in C++17 and removed in C++20.
                                                      # It has been replaced by std::uncaught_exceptions (plural).

  EXTRA_CXX_FLAGS+=" -fnothrow-opt"  # Reduce or eliminate the text size overhead for throw(). Further information:
                                     # - throw():
                                     #   - Since  C++17: Same as noexcept(true), so this flag may actually have no effect.
                                     #   - Before C++17: On exception, it calls std::unexpected().
                                     #                   Performs stack unwinding and can eventually recover.
                                     # - noexcept: on exception, no stack unwinding, calls std::terminate().

  EXTRA_CXX_FLAGS+=" -fno-enforce-eh-specs"  # Don't generate code to check for violation of exception specifications at runtime.

fi


# The Arduino Framework specifies --param max-inline-insns-single=500,
# but I am not sure whether that is a good idea.
if false; then
  EXTRA_C_AND_CXX_FLAGS+=" --param max-inline-insns-single=500"
fi


# See UserImplementationOfAssert.h for all possible assertion types.
# For debug builds, the size of the final binary depends on the assertion type.
ASSERT_TYPE=ASSERT_TYPE_FULL

AppendIncludeDir EXTRA_CPP_FLAGS "$srcdir/src/UserImplementationOfAssert"

EXTRA_CPP_FLAGS+=" -DINCLUDE_USER_IMPLEMENTATION_OF_ASSERT"
EXTRA_CPP_FLAGS+=" -DASSERT_TYPE=$ASSERT_TYPE"

# Needed by NewlibSyscalls.cpp.
EXTRA_CPP_FLAGS+=" -DASSERT_MSG_BUFSIZE=300"


# Sometimes, you want to set the C and C++ language standard.
# For example, with -std=c++11 you do not get vsnprintf.
# The defaults are:
#  GCC  7:  gnu11, gnu++14
#  GCC  8:  gnu18, gnu++14
#  GCC  9:  gnu18, gnu++14
#  GCC 10:  gnu18, gnu++14
#  GCC 11:  gnu18, gnu++17
if $IS_GCC_8_OR_LATER; then
  # Alternatively, use -std=c18 and -std=c++17 to prevent getting
  # inadvertently used to GCC-specific language extensions.
  EXTRA_C_FLAGS+=" -std=gnu18"
  EXTRA_CXX_FLAGS+=" -std=gnu++17"
fi


EXTRA_CPP_FLAGS+=" -D_GNU_SOURCE"  # This select the right version of strerror_r().


if $NEEDS_ATMEL_SOFTWARE_FRAMEWORK; then

  EXTRA_CPP_FLAGS+=" -DBOARD=ARDUINO_DUE_X"

  # Needed for both CMSIS and the lib under "arduino-1.5.2/hardware/arduino/sam/cores".
  EXTRA_CPP_FLAGS+=" -D__SAM3X8E__"

  EXTRA_CPP_FLAGS+=" -DSAM3XA_SERIES"
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
  # The DebugDue Firmware does not use a composite device, but defines a single CDC device,
  # so that the standard Arduino Due INF driver does not work even if you use the same PID.
  #
  # Therefore, I have chosen a different PID of 0x1234. You can choose your own,
  # but then you will need to modify the .INF driver file and reinstall it on Windows.

  EXTRA_CPP_FLAGS+=" -DUSB_VID=0x2341 -DUSB_PID=0x1234"

  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/sam/drivers/pmc"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/sam/boards"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/boards"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/services/clock"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/services/sleepmgr"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/services/usb/class/cdc"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/services/usb/class/cdc/device"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/services/usb/udc"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/services/usb"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/sam/utils/cmsis/sam3x/include"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/sam/utils/cmsis/sam3x/source/templates"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/thirdparty/CMSIS/Include"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/sam/utils"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/sam/utils/preprocessor"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/sam/utils/header_files"
  AppendSystemIncludeDir ASF_INCLUDE_COMMON "$srcdir/src/AsfSrc/common/utils"

  EXTRA_CPP_FLAGS+="$ASF_INCLUDE_COMMON"

  AppendSystemIncludeDir EXTRA_CPP_FLAGS "$srcdir/src/AsfSrc/sam/drivers/pio"
  AppendSystemIncludeDir EXTRA_CPP_FLAGS "$srcdir/src/AsfSrc/sam/drivers/rstc"
  AppendSystemIncludeDir EXTRA_CPP_FLAGS "$srcdir/src/AsfSrc/sam/drivers/wdt"
  AppendSystemIncludeDir EXTRA_CPP_FLAGS "$srcdir/src/AsfSrc/sam/drivers/adc"
  AppendSystemIncludeDir EXTRA_CPP_FLAGS "$srcdir/src/AsfSrc/sam/drivers/uart"

fi

AC_SUBST(ASF_INCLUDE_COMMON)


# --- Compiler warning configuration, begin ---

EXTRA_C_AND_CXX_FLAGS+=" -fdiagnostics-show-option"

# The static analyzer is very slow but can help find bugs.
# It is specially useful when building with LTO.
#  EXTRA_C_AND_CXX_FLAGS+=" -fanalyzer"

EXTRA_C_AND_CXX_FLAGS+=" -Wall -Wextra"

EXTRA_C_AND_CXX_FLAGS+=" -Wundef"  # It is a very common error to forget defining a symbol, and then "#if SYMBOL" will not fail or warn you,
                                   # because such undefined identifiers are quietly replaced with zero.
                                   # This warning tries to help prevent such mistakes.
                                   # -Wundef is not enabled automatically by -Wall, at least with GCC 9.3.

EXTRA_C_AND_CXX_FLAGS+=" -Wshadow"  # Variables with the same name in different scopes can lead to confusion.
EXTRA_C_AND_CXX_FLAGS+=" -Wpointer-arith" # Warn on sizeof(void), and on arithmetic with NULL.
EXTRA_C_AND_CXX_FLAGS+=" -Wcast-qual"  # For example, casting "const char *" to "char *".
EXTRA_C_AND_CXX_FLAGS+=" -Wunreachable-code"
EXTRA_C_AND_CXX_FLAGS+=" -Wredundant-decls"
EXTRA_C_AND_CXX_FLAGS+=" -Wwrite-strings"
EXTRA_C_AND_CXX_FLAGS+=" -Wfloat-equal"
EXTRA_C_AND_CXX_FLAGS+=" -Wformat=2"  # Also enables '-Wformat-nonliteral'.
EXTRA_C_AND_CXX_FLAGS+=" -Wformat-signedness"
EXTRA_C_AND_CXX_FLAGS+=" -Wformat-truncation=2"
EXTRA_C_AND_CXX_FLAGS+=" -Wunknown-pragmas"
EXTRA_C_AND_CXX_FLAGS+=" -Wattributes"
EXTRA_C_AND_CXX_FLAGS+=" -Wtrampolines"
EXTRA_C_AND_CXX_FLAGS+=" -Wpacked"
EXTRA_C_AND_CXX_FLAGS+=" -Wnormalized=nfc"
EXTRA_C_AND_CXX_FLAGS+=" -Wpragmas"
EXTRA_C_AND_CXX_FLAGS+=" -Wlogical-op"
EXTRA_C_AND_CXX_FLAGS+=" -Wduplicated-branches"
EXTRA_C_AND_CXX_FLAGS+=" -Wduplicated-cond"
EXTRA_C_AND_CXX_FLAGS+=" -Wunsafe-loop-optimizations"
EXTRA_C_AND_CXX_FLAGS+=" -Wstack-protector"
EXTRA_C_AND_CXX_FLAGS+=" -Wbuiltin-macro-redefined"
EXTRA_C_AND_CXX_FLAGS+=" -Wcpp"
EXTRA_C_AND_CXX_FLAGS+=" -Wendif-labels"
EXTRA_C_AND_CXX_FLAGS+=" -Wdeprecated"
EXTRA_C_AND_CXX_FLAGS+=" -Wdeprecated-declarations"
EXTRA_C_AND_CXX_FLAGS+=" -Wdiv-by-zero"
EXTRA_C_AND_CXX_FLAGS+=" -Wdouble-promotion"  # Types 'float' and 'double' are not the same, especially if the FPU only supports single precision.

EXTRA_C_AND_CXX_FLAGS+=" -Wsign-conversion"  # This warning can bee too noisy. At the moment, I have managed to live with it.
EXTRA_C_AND_CXX_FLAGS+=" -Wconversion"       # Warn for implicit conversions that may alter a value.
                                             # This warning can bee too noisy. At the moment, I have managed to live with it.
EXTRA_C_AND_CXX_FLAGS+=" -Wfloat-conversion"

if $IS_GCC_8_OR_LATER; then
  :
else
  EXTRA_C_AND_CXX_FLAGS+=" -Wabi"  # Avoid too many warnings with GCC 7.3.
fi

EXTRA_C_FLAGS+=" -Wc++-compat"
EXTRA_C_FLAGS+=" -Wstrict-prototypes"
EXTRA_C_FLAGS+=" -Wbad-function-cast"
EXTRA_C_FLAGS+=" -Wnested-externs"

EXTRA_C_FLAGS+=" -Wmissing-prototypes"      # "no previous prototype"   warning for C   mode.
EXTRA_CXX_FLAGS+=" -Wmissing-declarations"  # "no previous declaration" warning for C++ mode.


EXTRA_C_FLAGS+=" -Wpointer-to-int-cast"

# You may want to disable this warning with certain versions of GCC:
if false; then
  EXTRA_C_AND_CXX_FLAGS+=" -Wno-psabi"  # Suppresses warning "the mangling of 'va_list' has changed in GCC 4.4".
                                        # I do not know yet if this warning should be taken seriously.
fi

# This GCC option apparently does not work with LTO, at least with GCC 4.9.3:
#   #pragma GCC diagnostic ignored "-Wframe-larger-than="
# Therefore, enable this warning only in Debug-Builds:
if $IS_DEBUG_BUILD; then
  EXTRA_C_AND_CXX_FLAGS+=" -Wframe-larger-than=400"  # This limit of 400 bytes is rather arbitrary. But it helps.
  # Option -Wstack-usage is better, as it considers things like alloca() and variable-length arrays.
  # However, you then get the occasional warning "stack usage computation not supported for this target",
  # at least when using inline assembly.
fi

EXTRA_CXX_FLAGS+=" -Wsuggest-attribute=format"
EXTRA_CXX_FLAGS+=" -Wsuggest-attribute=malloc"
# EXTRA_CXX_FLAGS+=" -Wsuggest-attribute=pure"
# EXTRA_CXX_FLAGS+=" -Wsuggest-attribute=noreturn"
# EXTRA_CXX_FLAGS+=" -Wsuggest-attribute=cold"

EXTRA_CXX_FLAGS+=" -Wunused-const-variable"  # This C++ warning must be enabled explicitly, that is,
                                             # neither -Wall nor -Wunused-variable enable it for C++.
EXTRA_CXX_FLAGS+=" -Wnoexcept"
EXTRA_CXX_FLAGS+=" -Wsign-promo"
EXTRA_CXX_FLAGS+=" -Wsuggest-override"
EXTRA_CXX_FLAGS+=" -Wuseless-cast"
EXTRA_CXX_FLAGS+=" -Wzero-as-null-pointer-constant"
EXTRA_CXX_FLAGS+=" -Wextra-semi"
EXTRA_CXX_FLAGS+=" -Wcomma-subscript"
EXTRA_CXX_FLAGS+=" -Wredundant-tags"
EXTRA_CXX_FLAGS+=" -Wvolatile"  # Enabled by default with '-std=c++20'.


# --- Compiler warning configuration, end ---


PUBLISH_BOOLEAN_VARIABLE(IS_EMPTY_FIRMWARE)
PUBLISH_BOOLEAN_VARIABLE(IS_QEMU_FIRMWARE)
PUBLISH_BOOLEAN_VARIABLE(IS_DEBUG_DUE)
PUBLISH_BOOLEAN_VARIABLE(NEEDS_BARE_METAL)
PUBLISH_BOOLEAN_VARIABLE(NEEDS_ATMEL_SOFTWARE_FRAMEWORK)


USE_GOLD_LINKER=false  # The newer Gold Linker does not seem compatible yet with the linker script files for the traditional linker,
                       # at least for a bare-metal firmware like this one.
PUBLISH_BOOLEAN_VARIABLE(USE_GOLD_LINKER)


# --- Set the final variables.

AM_CPPFLAGS="$EXTRA_CPP_FLAGS"
AM_CFLAGS="$BUILD_FLAGS $EXTRA_C_AND_CXX_FLAGS $EXTRA_C_FLAGS"
AM_CXXFLAGS="$BUILD_FLAGS $EXTRA_C_AND_CXX_FLAGS $EXTRA_CXX_FLAGS"
AM_CCASFLAGS="$BUILD_FLAGS"
AM_LDFLAGS="$EXTRA_LD_FLAGS"

AC_SUBST(AM_CPPFLAGS)
AC_SUBST(AM_CFLAGS)
AC_SUBST(AM_CXXFLAGS)
AC_SUBST(AM_CCASFLAGS)
AC_SUBST(AM_LDFLAGS)

# ----------------------------------------

# If you update this line, please update SUBDIRS in Makefile.am too.
#
# I have not found a way to pass a variable to AC_CONFIG_FILES, as AC_CONFIG_FILES simply will not expand a shell variable.
# Therefore, all possible makefiles are listed here, even if not all of them are compiled later (see Makefile.am).
# As a potential work-around, autogen.sh could generate an .m4 file with the right (shorter) list, which would then be included here.
AC_CONFIG_FILES(
  Makefile
)

AC_OUTPUT


# Optionally show the tool versions this script is using.

declare -r SHOW_TOOL_VERSIONS=false

if $SHOW_TOOL_VERSIONS; then

  echo "Tool versions:"

  TMP_TXT="$($am_make --version)"
  head -n 1 - <<<"- $TMP_TXT"

  TMP_TXT="$(autoconf --version)"
  head -n 1 - <<<"- $TMP_TXT"

  TMP_TXT="$(automake --version)"
  head -n 1 - <<<"- $TMP_TXT"

  # We could also show the libtool version here, but we are not using it at all,
  # so it may not even be installed.
  #
  # The GCC version is shown further above.
fi


# Check that we did actually leave user variables to the end user.
for varName in "${USER_VARIABLES[[@]]}"; do
  if [[ ! -z "${!varName}" ]]; then
    AC_MSG_ERROR([Variable $varName should be undefined or empty, because it is reserved for the end user. However, $varName has the following value: ${!varName}])
  fi
done

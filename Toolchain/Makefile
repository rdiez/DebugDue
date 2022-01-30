
# Run "make help" for information about how to use this makefile.
#
# Copyright (c) 2013-2022 - R. Diez - Licensed under the GNU AGPLv3.


# ------- Standard Configuration -------

THIS_MAKEFILE_DIR := $(shell readlink --verbose --canonicalize -- "$(CURDIR)")

MAKEFILE_TOOLS_DIR        := $(THIS_MAKEFILE_DIR)/Tools
MAKEFILE_PATCHES_DIR      := $(THIS_MAKEFILE_DIR)/Patches
CROSS_TOOLCHAIN_BUILD_DIR := $(THIS_MAKEFILE_DIR)/Tmp
TARBALLS_DOWNLOAD_DIR     := $(THIS_MAKEFILE_DIR)/Tarballs

include $(MAKEFILE_TOOLS_DIR)/MakefileCommon.mk

RUN_AND_REPORT_TOOL_PATH := $(MAKEFILE_TOOLS_DIR)/RunAndReport.sh


# Variable CROSS_TOOLCHAIN_BUILD_DIR is often overriden on the 'make' command line,
# so checking just THIS_MAKEFILE_DIR is not enough.
$(call check_variable_non_empty_and_contains_no_whitespace,CROSS_TOOLCHAIN_BUILD_DIR)


TARGET_NAME_ALL := all
TARGET_NAME_HELP := help
TARGET_NAME_CLEAN := clean
TARGET_NAME_CHECK := check
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET := download-tarballs-from-internet
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER := download-tarballs-from-file-server
TARGET_NAME_TEST_MAKEFLAGS := test-makeflags


$(call poison_variable_if_undef_or_empty_or_contains_whitespace,CROSS_TOOLCHAIN_DIR)
$(call poison_variable_if_undef_or_empty_or_contains_whitespace,PATH_TO_TARBALLS_ON_FILE_SERVER)


# ------- User Configuration -------

# - Binutils: https://www.gnu.org/software/binutils/
# - Building the GMP, MPFR and MPC is optional. If you do not build them,
#   the ones installed on the host system are used instead.
#   The corresponding package names in Ubuntu/Debian are libgmp-dev, libmpfr-dev and libmpc-dev.
#   This makefile can either build these 3 libraries itself, or none of them.
#   - GMP:  https://gmplib.org/
#   - MPFR: https://www.mpfr.org/
#   - MPC:  http://www.multiprecision.org/mpc/
#
# You can check out GCC's contrib/download_prerequisites for inspiration
# on libraries and version numbers. Unfortunately, that script looks
# outdated and has no comments about why a version was chosen or skipped.
#
# We could also download and build the isl (Integer Set Library),
# availabe under http://isl.gforge.inria.fr/, in order to enable Graphite optimisations in GCC.
# See GCC's configuration option '--with-isl'.

VERSION_SET := VersionSet9

ifeq ($(VERSION_SET),VersionSet1)

  BINUTILS_VERSION := 2.30

  # Unfortunately, GMP version 6.1.2 is known to fail "make check" test 't-get_d_2exp' when building with LTO.
  GMP_VERSION := 6.1.2

  MPFR_VERSION := 3.1.6
  MPC_VERSION := 1.0.3
  GCC_VERSION := 7.3.0
  NEWLIB_VERSION := 3.0.0.20180226
  GDB_VERSION := 8.1

else ifeq ($(VERSION_SET),VersionSet2)

  BINUTILS_VERSION := 2.32

  # Unfortunately, GMP version 6.1.2 is known to fail "make check" test 't-get_d_2exp' when building with LTO.
  # But it looks alright With the GMP version 6.2.0 and GCC 9.3, as used in VersionSet3 below.
  GMP_VERSION := 6.1.2

  MPFR_VERSION := 4.0.2
  MPC_VERSION := 1.1.0
  GCC_VERSION := 8.3.0
  NEWLIB_VERSION := 3.1.0

  # Do not use GDB versions 8.1.x or 8.2.x with GCC 8.x, or you will
  # immediately hit the following issue when debugging binaries built with LTO:
  #   Assertion: SYMBOL_LANGUAGE (sym) == DICT_LANGUAGE (dict)->la_language
  #   https://sourceware.org/bugzilla/show_bug.cgi?id=23010
  GDB_VERSION := 8.3

else ifeq ($(VERSION_SET),VersionSet3)

  BINUTILS_VERSION := 2.34
  GMP_VERSION := 6.2.0
  MPFR_VERSION := 4.0.2
  MPC_VERSION := 1.1.0
  GCC_VERSION := 9.3.0
  NEWLIB_VERSION := 3.3.0
  GDB_VERSION := 9.1

else ifeq ($(VERSION_SET),VersionSet4)

  BINUTILS_VERSION := 2.35.1
  GMP_VERSION := 6.2.0
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.0
  GCC_VERSION := 9.3.0
  NEWLIB_VERSION := 3.3.0
  GDB_VERSION := 9.2

else ifeq ($(VERSION_SET),VersionSet5)

  BINUTILS_VERSION := 2.36.1
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 10.2.0
  NEWLIB_VERSION := 4.1.0
  GDB_VERSION := 10.1

else ifeq ($(VERSION_SET),VersionSet6)

  BINUTILS_VERSION := 2.36.1
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 10.3.0
  NEWLIB_VERSION := 4.1.0
  GDB_VERSION := 10.1

else ifeq ($(VERSION_SET),VersionSet7)

  BINUTILS_VERSION := 2.36.1
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 10.3.0
  NEWLIB_VERSION := 4.1.0
  GDB_VERSION := 10.2

else ifeq ($(VERSION_SET),VersionSet8)

  BINUTILS_VERSION := 2.37
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 10.3.0
  NEWLIB_VERSION := 4.1.0
  GDB_VERSION := 11.1

else ifeq ($(VERSION_SET),VersionSet9)

  BINUTILS_VERSION := 2.37
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 11.2.0
  NEWLIB_VERSION := 4.1.0
  # PICOLIBC_VERSION := 1.7.4
  GDB_VERSION := 11.1

else
  $(error Invalid configuration set "$(VERSION_SET)")
endif


ifdef NEWLIB_VERSION
  ifdef PICOLIBC_VERSION
    $(error Both NEWLIB_VERSION and PICOLIBC_VERSION are set)
  else
    TARGET_LIBC := newlib
  endif
else
  ifdef PICOLIBC_VERSION
    TARGET_LIBC := picolibc
    $(error Support for Picolibc is not ready yet)
  else
    $(error Either NEWLIB_VERSION or PICOLIBC_VERSION must be set)
  endif
endif


# Use the 'install-strip' target, instead of the usual 'install', in order to reduce the size
# of the installed binaries. For example, when building Binutils 2.30 with GCC 5.4.0,
# the installation size goes from 194 MiB to 26 MiB, a reduction of 87 %.
#
# Should ever need the debug symbols, for example to generate a call stack for a bug report,
# or to step through the code, you need to change this back to 'install'. But then
# you will probably want to build the toolchain binaries without optimisation.
# And do not forget to change option '-g0' below to '-g'.

INSTALL_TARGET := install-strip


# These are the compilation flags for the toolchain itself when running on the cross-compiling PC.
# HF stands for "Host Flags".
HF_COMMON :=

# Building without debug information cuts the Binutils build time alone with GCC 5.4.0 and
# "-O3 -march=native" on my Intel Core i3 M 380 from 5 minutes, 22 seconds to 4 minutes.
# You need to explicitly add -g0 to disable debug information, because some components
# automatically prepend the compiler flags with '-g'.
HF_COMMON += -g0


# The GCC phase 1 compiler is only used once to build Newlib and it is not worth optimising it.
HF_NO_OPT := -O0


HF_OPT :=

# The GCC compiler and the Binutils linker, among other components, need to do heavy lifting,
# so we want to optimise them as much as we can.
HF_OPT += -O3

# Building for the current CPU makes this toolchain not portable, but can yield
# a good performance boost, especially on newer CPUs.
HF_OPT += -march=native


# See the project's configure.ac file for more information about why we are
# not using "-flto=jobserver" here.
LTO_PARALLEL_LEVEL:=$(shell echo $$(( $$(getconf _NPROCESSORS_ONLN) + 1 )) )
HF_LTO := -flto=$(LTO_PARALLEL_LEVEL)


HOST_FLAGS_WITHOUT_OPT      := CFLAGS="$(HF_COMMON) $(HF_NO_OPT)"        CXXFLAGS="$(HF_COMMON) $(HF_NO_OPT)"
HOST_FLAGS_WITH_OPT         := CFLAGS="$(HF_COMMON) $(HF_OPT)"           CXXFLAGS="$(HF_COMMON) $(HF_OPT)"
HOST_FLAGS_WITH_OPT_AND_LTO := CFLAGS="$(HF_COMMON) $(HF_OPT) $(HF_LTO)" CXXFLAGS="$(HF_COMMON) $(HF_OPT) $(HF_LTO)"


# Setting ENABLE_DEBUG_TOOLCHAIN to '1' builds the toolchain with -DDEBUG in CFLAGS_FOR_TARGET and CXXFLAGS_FOR_TARGET,
# which enables debug code at least in Newlib's malloc implementation, and probably in other places too.
#
# It would be best to build both the debug and non-debug library versions, and that's probably what
# GCC's "multilib" support is all about, but I haven't figured it out yet.
# There is also the --enable-libstdcxx-debug switch, which builds separate C++ debug libraries too,
# but that only applies to the libstdc++. I also don't know yet how to link against those debug versions
# instead of the normal ones.

ENABLE_DEBUG_TOOLCHAIN := 0

TOOLCHAIN_TARGET_CPU := cortex-m3

# Not really used, see below for more information.
CONFIGURE_CACHE_FILENAME := $(CROSS_TOOLCHAIN_BUILD_DIR)/build-toolchain-local-cache-file.cache

# I have decided not to share a common cache file. Reasons are:
# 1) The 'configure' scripts from different projects are potentially called in parallel,
#    and I am not sure that updating cache files in parallel is safe.
# 2) Most projects create further "config.cache" files in their subprojects, so the caches
#    do not seem to get reused much.
#   CONFIG_CACHE_OPTION := --cache-file="$(CONFIGURE_CACHE_FILENAME)"
CONFIG_CACHE_OPTION := --config-cache

# Removing all error messages returned by strerror() saves program space on the target.
REMOVE_STRERROR_MESSAGES := 1

# Disabling the CPP exception buffer saves RAM on the target.
DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER := 1

# Recent GCC versions may require newer versions of the GMP, MPFR and MPC
# libraries than the ones available in your linux distribution.
# With this option you can choose whether to download and build these libraries too.
# Possible makefile improvement: We could calculate this variable automatically based on the presence of GMP_VERSION etc.
BUILD_GMP_MPFR_MPC := 1

SHOULD_WARN_ABOUT_REBUILDING_SOFTWARE := 1


# ------- Miscellaneous definitions -------

TARGET_ARCH := arm-none-eabi

SENTINEL_FILENAME_PREFIX := ToolchainBuilder-

PATH_DIR = $(CROSS_TOOLCHAIN_DIR)/bin


# If you are not calling recursive makefiles, but running other unrelated makefiles, you do not normally
# want to pass the MAKEFLAGS you got. For example, the top-level makefile is often called with options
# '--no-builtin-variables' and '--warn-undefined-variables', which could break other makefiles.
# Therefore, we want to clean MAKEFLAGS beforehand.
# However, we still want to pass on those flags related to GNU Make's job server. They look like this:
# - In GNU Make version 3.81:  MAKEFLAGS: --jobserver-fds=3,4 -j -- SOMEVAR=SOMEVALUE ...
# - In GNU Make version 4.2.1: MAKEFLAGS: -j3 --jobserver-auth=3,4 -- SOMEVAR=SOMEVALUE ...
# On Microsoft Windows, you may see something like "--jobserver-auth=some-name".
#
# Note that any variables set in the command-line arguments passed to GNU Make appear
# in MAKEFLAGS too after a '--' separator. Before filtering out the jobserver arguments,
# we should remove anything after the "--" separator, but that is hard to do with GNU Make.
# If you know how to code this, contributions are welcome. I have seen that you can use a recursive
# function to find the index of a word like '--' in a list, and then you could probably
# filter out the rest with built-in function 'wordlist'.
#
# We also want to pass flag '--output-sync=xxx' (aka '-Oxxx'), if present.
#
# Perhaps we should run the "make install" commands without any parallel flags at all, just in case.

EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS = $(strip $(filter -j%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-fds=%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-auth=%,$(MAKEFLAGS)) \
                                                $(filter -O%,$(MAKEFLAGS)))
EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS = export MAKEFLAGS="$(EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS)"


# ------- Build directory definitions -------

CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR)/$(SENTINEL_FILENAME_PREFIX)BuildDirSentinel
CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES := $(CROSS_TOOLCHAIN_BUILD_DIR)/ToolchainBuilder-LogFiles


# ------- Common C/C++ Compilation flags -------

# WARNING: The following components must be ABI compatible, which means they must be compiled
#          with similar CFLAGS:
# - Newlib.
#   Keep in mind that Newlib's configure.host may provide additional compilation flags.
#   The best thing to do is probably to run this makefile once and then look for the compilation flags
#   in the log output of some Newlib source file like "strlen.c".
# - GCC's libgcc und libstdc++ (and its libsupc++).
# - Your our application, so you will have to keep the CFLAGS/CXXFLAGS in your
#   own makefile in sync with this one.

COMMON_CFLAGS_FOR_TARGET :=


# --- Debug oder Release Toolchain.

ifeq ($(ENABLE_DEBUG_TOOLCHAIN), 0)
  COMMON_CFLAGS_FOR_TARGET += -g -Os
  TOOLCHAIN_KIND := Release (non-debug) toolchain.
else ifeq ($(ENABLE_DEBUG_TOOLCHAIN), 1)
  COMMON_CFLAGS_FOR_TARGET += -g -Og -DDEBUG
  TOOLCHAIN_KIND := Debug toolchain.
else
  $(error Variable ENABLE_DEBUG_TOOLCHAIN has invalid value "$(ENABLE_DEBUG_TOOLCHAIN)")
endif


# --- Target CPU.

FLAGS_NO_HARDWARE_FP := --without-fp --with-float=soft

ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m0)
  COMMON_CFLAGS_FOR_TARGET += -mcpu=cortex-m0 -mthumb
  GCC_FLOATING_POINT_FLAGS := $(FLAGS_NO_HARDWARE_FP)
else ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m3)
  COMMON_CFLAGS_FOR_TARGET += -mcpu=cortex-m3 -mthumb
  GCC_FLOATING_POINT_FLAGS := $(FLAGS_NO_HARDWARE_FP)
else ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m4f)
  COMMON_CFLAGS_FOR_TARGET += -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
  GCC_FLOATING_POINT_FLAGS := # No flags needed here.
else
  $(error Variable TOOLCHAIN_TARGET_CPU has invalid value "$(TOOLCHAIN_TARGET_CPU)")
endif


# --- Other flags.

# Frame pointers are generally useful in order to investigate crash dumps or to debug an optimised build.
# They do cost a little in terms of stack space, code space and performance, though.
COMMON_CFLAGS_FOR_TARGET += -fno-omit-frame-pointer
COMMON_CFLAGS_FOR_TARGET += -fdata-sections      # Keeps data in separate data sections, so they can be discarded if unused.
COMMON_CFLAGS_FOR_TARGET += -ffunction-sections  # Keeps functions in separate data sections, so they can be discarded if unused.

# I did one quick test, and enabling exceptions here did not add any code when building the toolchain with -Os
# and the application without exceptions enabled. Therefore, I am leaving exceptions enabled here
# even though the application might never not use them.
#   COMMON_CFLAGS_FOR_TARGET += -fno-exceptions


# ------- Binutils configuration -------

BINUTILS_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/binutils-$(BINUTILS_VERSION)
BINUTILS_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/binutils-$(BINUTILS_VERSION)-obj
BINUTILS_TAR_FILE := binutils-$(BINUTILS_VERSION).tar.xz

# Option --enable-plugins is necessary for Gold to understand the --plugin command-line switch that the GCC driver passes.
BINUTILS_GOLD_CONFIGURE_OPTIONS := --enable-gold=yes --enable-plugins

BINUTILS_UNTAR_SENTINEL := $(BINUTILS_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
BINUTILS_MAKEFILE := $(BINUTILS_OBJ_DIR)/Makefile
BINUTILS_MAKE_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
BINUTILS_INSTALL_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)BinutilsInstallSentinel
BINUTILS_INSTALL_SENTINEL_PHASE_1 := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)BinutilsInstallSentinelPhase1
BINUTILS_CHECK_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)CheckSentinel


# ------- GMP lib configuration -------

GMP_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gmp-$(GMP_VERSION)
GMP_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gmp-$(GMP_VERSION)-obj
GMP_TAR_FILE := gmp-$(GMP_VERSION).tar.bz2

GMP_UNTAR_SENTINEL := $(GMP_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
GMP_MAKEFILE := $(GMP_OBJ_DIR)/Makefile
GMP_MAKE_SENTINEL := $(GMP_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
GMP_INSTALL_SENTINEL := $(GMP_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GmpInstallSentinel
GMP_CHECK_SENTINEL := $(GMP_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GmpCheckSentinel


# According to GMP's documentation, when building for Windows:
#  "Static and DLL libraries can’t both be built, since certain export directives in gmp.h must be different."
# If you build GMP as a static library, MPFR and MPC can apparently only be built as static libraries too.
#
# Normally, the build scripts for all those libraries will try to build them both as static libraries
# and as shared objects, but this is waste of build time and disk space, since we only need
# one kind anyway, even on Linux.

FLAGS_TO_BUILD_GMP_ETC_AS_STATIC_ONLY_LIBS := --disable-shared --enable-static


# ------- MPFR lib configuration -------
#
# Older versions are still available on the website under "history", or on ftp://ftp.gnu.org/gnu/mpfr/ .

MPFR_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/mpfr-$(MPFR_VERSION)
MPFR_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/mpfr-$(MPFR_VERSION)-obj
MPFR_TAR_FILE := mpfr-$(MPFR_VERSION).tar.xz

MPFR_UNTAR_SENTINEL := $(MPFR_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
MPFR_MAKEFILE := $(MPFR_OBJ_DIR)/Makefile
MPFR_MAKE_SENTINEL := $(MPFR_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
MPFR_INSTALL_SENTINEL := $(MPFR_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpfrInstallSentinel
MPFR_CHECK_SENTINEL := $(MPFR_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpfrCheckSentinel


# ------- MPC lib configuration -------
#
# This libray can be downloaded from http://www.multiprecision.org/
# Version 1.1.0 has been released in the meantime, so that it builds against MPFR 4.0.x .

MPC_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/mpc-$(MPC_VERSION)
MPC_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/mpc-$(MPC_VERSION)-obj
MPC_TAR_FILE := mpc-$(MPC_VERSION).tar.gz

MPC_UNTAR_SENTINEL := $(MPC_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
MPC_MAKEFILE := $(MPC_OBJ_DIR)/Makefile
MPC_MAKE_SENTINEL := $(MPC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
MPC_INSTALL_SENTINEL := $(MPC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpcInstallSentinel
MPC_CHECK_SENTINEL := $(MPC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpcCheckSentinel


# ------- GCC configuration -------

# If your host compiler ist GCC version 7 or newer, you can enable LTO builds here.
# Unfortunately, this has stopped working when the cross-compiler is GCC version 11.1 or 11.2. The error message is:
#   /usr/bin/ld: /tmp/g++-mapper-server.98PJcy.ltrans0.ltrans.o: relocation R_X86_64_32 against `.rodata.str1.1' can not be used when making a PIE object; recompile with -fPIE
#   collect2: error: ld returned 1 exit status
#   make[3]: *** [Makefile:94: g++-mapper-server] Error 1
#   make[2]: *** [Makefile:10549: all-c++tools] Error 2
# This problem is very similar to this bug:
#   https://gcc.gnu.org/bugzilla/show_bug.cgi?id=98324
ENABLE_LTO_FOR_GCC_PHASE_2 := 0

# This enables building a debug version of GCC in phase 2, instead of a release version,
# which is only useful if you need to debug GCC itself.
GCC_ENABLE_DEBUG_BUILD := 0

ifeq ($(GCC_ENABLE_DEBUG_BUILD),1)
  # Note that HF_COMMON is ignored below. Use with care.
  GCC_PHASE_2_BUILD_FLAGS := CFLAGS="-O0 -g"  CXXFLAGS="-O0 -g"
else ifeq ($(ENABLE_LTO_FOR_GCC_PHASE_2),1)
  GCC_PHASE_2_BUILD_FLAGS := $(HOST_FLAGS_WITH_OPT_AND_LTO)
else
  GCC_PHASE_2_BUILD_FLAGS := $(HOST_FLAGS_WITH_OPT)
endif

# Usually, you install the GCC phase 1 to the same directory where everything else goes.
# Later on, GCC phase 2 will be installed in the same place, and will overwrite phase 1.
#
# However, it is cleaner to install GCC phase 1 separately. After all, you never know
# if all files from phase 1 will be correctly overwritten. Even if that is true today,
# it may change in the future. Besides, you may configure GCC phase 2 differently,
# so that it does not match all installed files from phase 1. For example, you may decide
# that you only need the C++ compiler in the final toolchain, in order to reduce the total
# toolchain build time and save disk space for the final toolchain. The C compiler from
# phase 1, needed to build the C runtime library, would then be left behind.
#
# The GCC configuration script finds the Binutils for the target using the '--prefix=/some/dir'
# configuration setting. Binutils does not need to be on the PATH when configuring or building GCC.
# For example, it will find tool /some/dir/arm-none-eabi/bin/ar .
#
# Option '--with-build-time-tools=/some/dir' did not work for me, but it may be worth
# investigating it further.
#
# The easiest solution I found is to install Binutils twice: once in the final --prefix destination
# for the final toolchain, and again into a separate phase 1 bin directory.
# I am using Binutils's "make install" option 'DESTDIR=/my/path' at the moment,
# which mirrors the full directory path inside that directory again.
#
# Notes kept about alternative option 'tooldir=/some/dir':
#   Binutils's "make install" option 'tooldir=/some/dir' installs only the short names like 'bin/ar'.
#   There is also a 'lib' subdirectory.
#   There is no 'arm-none-eabi' subdirectory.
#   The man pages are not installed there.
#   I wonder whether the 'arm-none-eabi' subdir and the man pages are still installed to the
#   --prefix=/some/dir specified during configuration.
#
# In case the separate phase 1 installation directory breaks, you can use variable
# INSTALL_GCC_PHASE_1_TO_SEPARATE_DIR to revert to the old method.

INSTALL_GCC_PHASE_1_TO_SEPARATE_DIR := 1

ifeq ($(INSTALL_GCC_PHASE_1_TO_SEPARATE_DIR),1)
  PHASE_1_DESTDIR     := $(CROSS_TOOLCHAIN_BUILD_DIR)/Phase1Bin
  # Note that $(CROSS_TOOLCHAIN_DIR) already starts with '/'.
  PHASE_1_INSTALL_DIR  = $(CROSS_TOOLCHAIN_BUILD_DIR)/Phase1Bin$(CROSS_TOOLCHAIN_DIR)
  PHASE_1_PATH_DIR     = $(CROSS_TOOLCHAIN_BUILD_DIR)/Phase1Bin$(CROSS_TOOLCHAIN_DIR)/bin
  GCC_PHASE_2_SET_PATH_DIR = PATH=$(PHASE_1_PATH_DIR):$$PATH
else
  PHASE_1_INSTALL_DIR  = $(CROSS_TOOLCHAIN_DIR)
  PHASE_1_PATH_DIR     = $(PATH_DIR)
  GCC_PHASE_2_PATH_DIR =
endif


GCC_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)
GCC_TAR_FILE := gcc-$(GCC_VERSION).tar.xz
GCC_UNTAR_SENTINEL := $(GCC_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel

GCC1_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)-obj-phase1
GCC1_MAKEFILE := $(GCC1_OBJ_DIR)/Makefile
GCC1_MAKE_SENTINEL := $(GCC1_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GccPhase1MakeSentinel
GCC1_INSTALL_SENTINEL := $(GCC1_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GccPhase1InstallSentinel

GCC2_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)-obj-phase2
GCC2_MAKEFILE := $(GCC2_OBJ_DIR)/Makefile
GCC2_MAKE_SENTINEL := $(GCC2_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GccPhase2MakeSentinel
GCC2_INSTALL_SENTINEL := $(GCC2_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GccPhase2InstallSentinel
GCC2_CHECK_SENTINEL := $(GCC2_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GccPhase2CheckSentinel

GCC_CFLAGS_FOR_TARGET := $(COMMON_CFLAGS_FOR_TARGET)
# GCC_CFLAGS_FOR_TARGET += -H  # Print the name of each header file included, useful during development of this makefile.

COMMON_GCC_OPTIONS =
COMMON_GCC_OPTIONS += $(CONFIG_CACHE_OPTION)

COMMON_GCC_OPTIONS += --target=$(TARGET_ARCH)
COMMON_GCC_OPTIONS += $(GCC_FLOATING_POINT_FLAGS)

COMMON_GCC_OPTIONS += --disable-nls           # --enable-nls lets GCC output diagnostics in languages other than American English.
COMMON_GCC_OPTIONS += --disable-shared
COMMON_GCC_OPTIONS += --disable-libssp        # Stack Protection for security. The firmware would need to support it too.
COMMON_GCC_OPTIONS += --disable-libgomp       # OpenMP support.
COMMON_GCC_OPTIONS += --disable-libmudflap    # Instruments code to detect dangling pointers.
COMMON_GCC_OPTIONS += --disable-libquadmath   # Support quadruple-precision floats ( __float128).
COMMON_GCC_OPTIONS += --disable-multilib
COMMON_GCC_OPTIONS += --disable-decimal-float  # May not be necessary.
COMMON_GCC_OPTIONS += --disable-fixed-point    # May not be necessary.
COMMON_GCC_OPTIONS += --enable-threads=single

COMMON_GCC_OPTIONS += --with-newlib

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  COMMON_GCC_OPTIONS += --with-gmp="$(CROSS_TOOLCHAIN_DIR)"
  COMMON_GCC_OPTIONS += --with-mpfr="$(CROSS_TOOLCHAIN_DIR)"
  COMMON_GCC_OPTIONS += --with-mpc="$(CROSS_TOOLCHAIN_DIR)"
endif

# The built-in C++ exception support code is often the only place that needs the standard file I/O
# support from the C run-time library. By disabling this necessity with "--disable-libstdcxx-verbose",
# if your embedded software does not use printf (to stdout) and the like, you will end up saving
# a sizable amount of code size.
# You can still use sprintf() and so on, because they do not write to files like stdout,
# but just to memory buffers.
COMMON_GCC_OPTIONS += --disable-libstdcxx-verbose

COMMON_GCC_OPTIONS += --with-gnu-ld --with-gnu-as

# It is not clearly documented what --enable-lto does.
# By looking at GCC's configure.ac, it looks like it enables LTO support by building the LTO plug-ins
# for the linker. This option is enabled by default on most interesting platforms.
# We could probably disable it and save some build time for the GCC phase 1,
# but we may want to build Newlib with LTO support in the future.
COMMON_GCC_OPTIONS += --enable-lto


ifeq ($(DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER),1)

  IS_GCC_5_X   := $(filter 5.%,$(GCC_VERSION))
  IS_GCC_6_X   := $(filter 6.%,$(GCC_VERSION))
  IS_GCC_7_X   := $(filter 7.%,$(GCC_VERSION))
  IS_GCC_8_X   := $(filter 8.%,$(GCC_VERSION))
  IS_GCC_9_X   := $(filter 9.%,$(GCC_VERSION))
  IS_GCC_10_X  := $(filter 10.%,$(GCC_VERSION))
  IS_GCC_11_X  := $(filter 11.%,$(GCC_VERSION))

  ifneq "$(or $(IS_GCC_5_X), $(IS_GCC_6_X), $(IS_GCC_7_X), $(IS_GCC_8_X), $(IS_GCC_9_X), $(IS_GCC_10_X), $(IS_GCC_11_X) )" ""
    # The patch for version 5.1.0 works in the next versions too.
    GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME := $(MAKEFILE_PATCHES_DIR)/GccDisableCppExceptionEmergencyBuffer-GCC-5.3.0.patch
  else
    $(error Unknown GCC version)
  endif

else

  GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME := this-patch-filename-should-not-be-used

endif


# ------- Newlib configuration -------

ifeq ($(TARGET_LIBC), newlib)

NEWLIB_TAR_FILE := newlib-$(NEWLIB_VERSION).tar.gz
NEWLIB_UNTAR_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/newlib-$(NEWLIB_VERSION)
NEWLIB_SRC_DIR := $(NEWLIB_UNTAR_DIR)
NEWLIB_NEWLIB_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/newlib-$(NEWLIB_VERSION)-obj

NEWLIB_UNTAR_SENTINEL := $(NEWLIB_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
NEWLIB_NEWLIB_MAKEFILE := $(NEWLIB_NEWLIB_OBJ_DIR)/Makefile
NEWLIB_NEWLIB_MAKE_SENTINEL := $(NEWLIB_NEWLIB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
NEWLIB_NEWLIB_INSTALL_SENTINEL := $(NEWLIB_NEWLIB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)NewlibNewlibInstallSentinel

NEWLIB_USER_IMPLEMENTATION_OF_ASSERT_PATCH_FILENAME := $(MAKEFILE_PATCHES_DIR)/NewlibUserImplementationOfAssert.patch

# If you are using an Newlib version from before 2018-01-17, you will have to use an older version
# of this patch stored next to the latest one.
NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME := $(MAKEFILE_PATCHES_DIR)/NewlibRemoveStrerrorMessages.patch

# NOTE: Newlib's switch --enable-target-optspace would add "-g -Os" to the compilation flags, but we have already done that in $(COMMON_CFLAGS_FOR_TARGET)
NEWLIB_CFLAGS := $(COMMON_CFLAGS_FOR_TARGET)

# Newlib's standard assert() implementation ends up calling fiprintf(), which pulls in loads of C runtime I/O functions,
# and we don't want that in our memory-constrained embedded environment.
NEWLIB_CFLAGS += -DHAVE_ASSERT_FUNC


NEWLIB_CFG_FLAGS =

NEWLIB_CFG_FLAGS += $(HOST_FLAGS_WITH_OPT_AND_LTO)
NEWLIB_CFG_FLAGS += --prefix="$(CROSS_TOOLCHAIN_DIR)"
NEWLIB_CFG_FLAGS += --target=$(TARGET_ARCH)
NEWLIB_CFG_FLAGS += $(CONFIG_CACHE_OPTION)

# libssp provides Stack Smashing Protection.
NEWLIB_CFG_FLAGS += --disable-libssp


# "reent small" means that sizeof(_reent) decreases from 1064 bytes to 240 bytes (tested with Newlib version 3.3.0).
# Because we are not using multithreading, these savings are only realised once.
# Unfortunately, "reent small" also means that some routines which need the lost space allocate it with malloc on first touch.
# For example, the first time you call rand(), it will call malloc. That is unexpected and my not be safe in all circumstances.
# Calling malloc inside an interrupt handler is normally unsafe.
# Therefore, if you are not really short on memory, this option should stay disabled (which is actually the default).
#
# If you need to enable "reent small", keep in mind that you will need to provide __assert_func() even in release builds
# (even if NDEBUG is defined), because Newlib calls it if malloc() fails when allocating any missing data from the _reent structure.
# I find this implementation choice unfortunate, because __assert_func should only be meant for assertions, and because
# of the implication that __assert_func() must always stop the firmware. I would have chosen another kind of 'abort' routine.
# Newlib version 3.1.0 did not require __assert_func(), and did not check whether malloc() failed, but Newlib version 3.3.0 does.
# You can disable this requirement in version 3.3.0 with --disable-newlib-reent-check-verify , but then you also lose such malloc() checks,
# which makes it unsafe.

ENABLE_NEWLIB_REENT_SMALL := 0

ifeq ($(ENABLE_NEWLIB_REENT_SMALL),1)
  NEWLIB_CFG_FLAGS += --enable-newlib-reent-small
else
  NEWLIB_CFG_FLAGS += --disable-newlib-reent-small
endif


NEWLIB_CFG_FLAGS += --disable-newlib-multithread


# The "nano formatted io" functions are alternative implementations of printf etc.
# that need less program space. Wide-char routines like wprintf are not affected,
# but chances are that you are not using those, as it's mostly ASCII or UTF-8 nowadays.
# The trouble is, the 'nano' alternatives are missing support for many useful C99 additions like these:
# - %z for printing the size_t type.
# - %ll for printing "long long" integers, normally 64-bits long.
#   PRIu64 will probably fail.
# - %hhu for 8-bit integers, which may make PRIu8 fail, if it is not using the older "hu" definition.
# - Positional printf arguments (actually a POSIX extension, and not C99).

ENABLE_NEWLIB_NANO_FORMATTED_IO := 0

ifeq ($(ENABLE_NEWLIB_NANO_FORMATTED_IO),1)
  NEWLIB_CFG_FLAGS += --enable-newlib-nano-formatted-io
else
  # This path needs around 7 kB more for a Cortex-M3 CPU target.
  # Note that the following flags are ignored if --enable-newlib-nano-formatted-io is used.
  NEWLIB_CFG_FLAGS += --enable-newlib-io-pos-args
  NEWLIB_CFG_FLAGS += --enable-newlib-io-c99-formats
  NEWLIB_CFG_FLAGS += --enable-newlib-io-long-long
endif


# Enabling float support in printf etc. is costly with the current Newlib implementation.
# It uses arbitrary-precision math code which allocates a lot of RAM,
# and has no robust failure modes when it runs out of memory.
NEWLIB_CFG_FLAGS += --disable-newlib-io-float
NEWLIB_CFG_FLAGS += --disable-newlib-io-long-double

NEWLIB_CFG_FLAGS += --disable-newlib-iconv
NEWLIB_CFG_FLAGS += --disable-newlib-iconv-external-ccs
NEWLIB_CFG_FLAGS += --disable-newlib-mb
NEWLIB_CFG_FLAGS += --disable-shared
NEWLIB_CFG_FLAGS += --disable-multilib

# I could not find a good reason why atexit() should be in struct _reent, so make it global.
#
# Notes about atexit memory consumption:
#   In Newlib, _ATEXIT_SIZE is 32 because of ANSI conformance, so each atexit block has 32 function pointers.
#   The associated arguments consume sizeof( struct _on_exit_args ) = 264 bytes.
#   And there is at least one, see _atexit0 and _global_atexit0.
NEWLIB_CFG_FLAGS += --enable-newlib-global-atexit

# You may wonder whether you need --disable-newlib-atexit-dynamic-alloc.
# But we are using --enable-newlib-global-atexit here, the project is building with -fno-use-cxa-atexit
# and the firmware is checking on start-up that there are no atexit entries,
# so it does not really matter: much of the atexit() support shold be optimised away.


# The full version of malloc uses 'bins' and is meant to be a good all-round allocator.
# But it starts off with an array in RAM called __malloc_av_ that weighs 1032 bytes,
# at least for a Cortex-M3 CPU target, so it is not a good choice for very
# constrained targets that don't do a lot of allocation.
# The trouble is, the 'nano' version is Newlib, as of April 2021, is known to be
# suboptimal in many normal scenarios.
NEWLIB_CFG_FLAGS += --enable-newlib-nano-malloc

# About --disable-libgloss and --disable-newlib-supplied-syscalls:
#
#   Newlib can provide syscalls like _sbrk(), which are also commonly needed, and
#   Libgloss normally provides crt0.o , which gets automatically added to the linker object file list,
#   and _exit(), which is needed by the most simple of programs. The configuration switches
#   below disable those features, because we are going to be providing custom versions for our board.
#   This means that autoconf will fail to detect the cross-compiler,
#   the error message is then: "error: C compiler cannot create executables".
#
#   If you enable the features above, then you will find it hard to write an Automake makefile
#   that links the files in the right order so as to override _sbrk() and so on with your own versions.
#
#   The correct way to fix this problem would be to modify Libgloss in order to provide
#   the stuff needed by our board. This way, a standard toolchain would be able to build for our board
#   with no additional linker files, etc. However, that would mean a lot of work, especially at the beginning,
#   when it's not clear yet what belongs in a common library and what doesn't.
#
#   Therefore, for the time being I am using undocumented macro AC_NO_EXECUTABLES in the autoconf project,
#   in order to work-around the error message described above.
#
NEWLIB_CFG_FLAGS += --disable-libgloss
NEWLIB_CFG_FLAGS += --disable-newlib-supplied-syscalls

endif


# ------- Picolibc configuration -------

ifeq ($(TARGET_LIBC), picolibc)

  PICOLIBC_TAR_FILE := picolibc-$(PICOLIBC_VERSION).tar.xz

  PICOLIBC_UNTAR_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/picolibc-$(PICOLIBC_VERSION)
  PICOLIBC_SRC_DIR := $(PICOLIBC_UNTAR_DIR)
  PICOLIBC_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/picolibc-$(PICOLIBC_VERSION)-obj

  # This file will be automatically generated in the future.
  PICOLIBC_TARGET_FLAGS_FILENAME := ToolchainBuilder-cross-$(TARGET_ARCH).txt

  # Many years ago compilers could not optimise and emit debug information at the same time,
  # so libg.a was a version of libc.a without optimisation and with debugging information.
  # If the -g to produce debugging information is present, GCC will link with libg.a.
  # Most GCC targets stopped using libg.a a long time ago, but the embedded targets
  # apparently continue to use it.
  # Nowadays, we will just link libg.a to libc.a .
  PICOLIBC_LIBC_INSTALLATION_DIR = $(CROSS_TOOLCHAIN_DIR)/$(TARGET_ARCH)/lib

  PICOLIBC_UNTAR_SENTINEL := $(PICOLIBC_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
  PICOLIBC_CONFIGURE_SENTINEL :=$(PICOLIBC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)ConfigureSentinel
  PICOLIBC_MAKE_SENTINEL := $(PICOLIBC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
  PICOLIBC_INSTALL_SENTINEL := $(PICOLIBC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)InstallSentinel

  PICOLIBC_CFG_FLAGS =

  PICOLIBC_CFG_FLAGS += -Dincludedir="$(TARGET_ARCH)/include"
  PICOLIBC_CFG_FLAGS += -Dlibdir="$(TARGET_ARCH)/lib"

  # 'picocrt' provides crt0.o, which initialises the C environment.
  # Our embedded application will be doing the initialisation itself.
  PICOLIBC_CFG_FLAGS += -Dpicocrt=false

  # 'picolib' provides startup helpers like the ARM interrupt vector, TLS support and sbrk.
  # Our embedded application will provide its own interrupt vector, its own sbrk,
  # and has no threading, so it does not need TLS.
  PICOLIBC_CFG_FLAGS += -Dpicolib=false

  # Enable C99 support in IO functions like printf/scanf.
  # Note that Picolib's tinystdio is still missing support for positional arguments like "%1$",
  # as of Picolibc version 1.7.4 from November 2021. That is actually a POSIX extension, and not C99.
  PICOLIBC_CFG_FLAGS += -Dio-c99-formats=true

  # Enable long long (normally 64-bits) type support in IO functions like printf/scanf.
  PICOLIBC_CFG_FLAGS += -Dio-long-long=true

  PICOLIBC_CFG_FLAGS += -Dthread-local-storage=false

endif


# ------- GDB configuration -------

GDB_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gdb-$(GDB_VERSION)
GDB_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gdb-$(GDB_VERSION)-obj
GDB_TAR_FILE := gdb-$(GDB_VERSION).tar.xz

GDB_UNTAR_SENTINEL := $(GDB_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
GDB_MAKEFILE := $(GDB_OBJ_DIR)/Makefile
GDB_MAKE_SENTINEL := $(GDB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
GDB_INSTALL_SENTINEL := $(GDB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GdbInstallSentinel


# This enables building a debug version of GDB, instead of a release version,
# which is only useful if you need to debug GDB itself.
GDB_ENABLE_DEBUG_BUILD := 0

GDB_BUILD_FLAGS =

ifeq ($(GDB_ENABLE_DEBUG_BUILD),1)
  # GDB is written in C only, so CXXFLAGS is not needed yet. But it might be necessary in the future.
  GDB_BUILD_FLAGS += CFLAGS="-O0 -g"  CXXFLAGS="-O0 -g"
else
  GDB_BUILD_FLAGS += $(HOST_FLAGS_WITH_OPT_AND_LTO)
endif

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  GDB_BUILD_FLAGS += --with-mpfr="$(CROSS_TOOLCHAIN_DIR)"
  GDB_BUILD_FLAGS += --with-gmp="$(CROSS_TOOLCHAIN_DIR)"
endif

# We cannot use INSTALL_TARGET here, because unfortunately GDB does not support the 'install-strip' target,
# at least as of versions 8.1 and 9.1. The error message is about not finding makefile recipes for targets
# 'install-strip', or 'install-strip-readline' and 'install-strip-sim'.
# I reported this issue, and the fix is targetted at GDB version 10.1:
#   https://sourceware.org/bugzilla/show_bug.cgi?id=24572
GDB_INSTALL_TARGET := install


# ----------------- Create the directory where the toolchain build files (object files, etc) will land -----------------

# This rule used to just creates a directory. Instead of a sentinel file for this rule, we could have used an "order-only prerequisite".
# But now other files are created inside that directory.
$(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL):
	echo && \
	echo "Creating directory \"$(CROSS_TOOLCHAIN_BUILD_DIR)\"..." && \
	mkdir --parents -- "$(CROSS_TOOLCHAIN_BUILD_DIR)" && \
	mkdir -- "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)" && \
	{ echo "Target CPU: $(TOOLCHAIN_TARGET_CPU)" && echo "Toolchain kind: $(TOOLCHAIN_KIND)"; } >"$(CROSS_TOOLCHAIN_BUILD_DIR)/ToolchainInfo.txt" && \
	echo "Creation of directory \"$(CROSS_TOOLCHAIN_BUILD_DIR)\" finished." >"$(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)"


# ----------------- Build Binutils -----------------

$(BINUTILS_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(BINUTILS_TAR_FILE) ..." && \
	if [ -d "$(BINUTILS_SRC_DIR)" ]; then rm -rf -- "$(BINUTILS_SRC_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(BINUTILS_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking Binutils finished." >"$(BINUTILS_UNTAR_SENTINEL)" && \
	echo "Unpacking Binutils finished."

$(BINUTILS_MAKEFILE): $(BINUTILS_UNTAR_SENTINEL)
	echo && \
	echo "Configuring Binutils from $(BINUTILS_SRC_DIR)/ to $(BINUTILS_OBJ_DIR)/" && \
	if [ -d "$(BINUTILS_OBJ_DIR)" ]; then rm -rf -- "$(BINUTILS_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(BINUTILS_OBJ_DIR)" && \
	pushd "$(BINUTILS_OBJ_DIR)" >/dev/null && \
	echo "Help text from the 'configure' script:" && \
	$(BINUTILS_SRC_DIR)/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsConfigHelp.txt" && \
	echo && \
	echo "Configuring:" && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "BinutilsConfig" \
	  "BinUtils Configuration" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsConfig.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsConfig.report" \
	  $(BINUTILS_SRC_DIR)/configure \
	    $(CONFIG_CACHE_OPTION)  \
	    $(HOST_FLAGS_WITH_OPT_AND_LTO) \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --target=$(TARGET_ARCH) \
	    $(BINUTILS_GOLD_CONFIGURE_OPTIONS) \
	    --disable-nls && \
	popd >/dev/null && \
	echo "The Binutils configuration has finished."

$(BINUTILS_MAKE_SENTINEL): $(BINUTILS_MAKEFILE)
	echo && \
	echo "Building Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "BinutilsMake" \
	  "BinUtils Make" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsMake.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsMake.report" \
	  $(MAKE) -C "$(BINUTILS_OBJ_DIR)" && \
	echo "The Binutils build has finished." >"$(BINUTILS_MAKE_SENTINEL)" && \
	echo "The Binutils build has finished."

$(BINUTILS_INSTALL_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo && \
	echo "Installing Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "BinutilsInstall" \
	  "BinUtils Install" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsInstall.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsInstall.report" \
	  $(MAKE) -C "$(BINUTILS_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The Binutils installation has finished." >"$(BINUTILS_INSTALL_SENTINEL)" && \
	echo "The Binutils installation has finished."

$(BINUTILS_INSTALL_SENTINEL_PHASE_1): $(BINUTILS_MAKE_SENTINEL)
	echo && \
	echo "Installing Binutils to separate phase 1 directory..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "BinutilsPhase1Install" \
	  "BinUtils Phase 1 Install" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsPhase1Install.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsPhase1Install.report" \
	  $(MAKE) -C "$(BINUTILS_OBJ_DIR)" DESTDIR="$(PHASE_1_DESTDIR)" "$(INSTALL_TARGET)" && \
	echo "The Binutils phase 1 installation has finished." >"$(BINUTILS_INSTALL_SENTINEL_PHASE_1)" && \
	echo "The Binutils phase 1 installation has finished."

$(BINUTILS_CHECK_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo && \
	echo "Checking Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "BinutilsCheck" \
	  "BinUtils Check" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsCheck.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsCheck.report" \
	  $(MAKE) -C "$(BINUTILS_OBJ_DIR)" check && \
	echo "The Binutils check has finished." >"$(BINUTILS_CHECK_SENTINEL)" && \
	echo "The Binutils check has finished."


# ----------------- Build GMP -----------------

$(GMP_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(GMP_TAR_FILE) ..." && \
	if [ -d "$(GMP_SRC_DIR)" ]; then rm -rf -- "$(GMP_SRC_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(GMP_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking GMP finished." >"$(GMP_UNTAR_SENTINEL)" && \
	echo "Unpacking GMP finished."

$(GMP_MAKEFILE): $(GMP_UNTAR_SENTINEL)
	echo && \
	echo "Configuring GMP from $(GMP_SRC_DIR)/ to $(GMP_OBJ_DIR)/" && \
	if [ -d "$(GMP_OBJ_DIR)" ]; then rm -rf -- "$(GMP_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GMP_OBJ_DIR)" && \
	pushd "$(GMP_OBJ_DIR)" >/dev/null && \
	echo "Help text from the 'configure' script:" && \
	$(GMP_SRC_DIR)/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpConfigHelp.txt" && \
	echo && \
	echo "Configuring:" && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GmpConfigure" \
	  "GMP Configure" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpConfigure.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpConfigure.report" \
	  $(GMP_SRC_DIR)/configure \
	    $(CONFIG_CACHE_OPTION)  \
	    $(HOST_FLAGS_WITH_OPT_AND_LTO) \
	    $(FLAGS_TO_BUILD_GMP_ETC_AS_STATIC_ONLY_LIBS) \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The GMP configuration has finished."

$(GMP_MAKE_SENTINEL): $(GMP_MAKEFILE)
	echo && \
	echo "Building GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GmpMake" \
	  "GMP Make" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpMake.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpMake.report" \
	  $(MAKE) -C "$(GMP_OBJ_DIR)" && \
	echo "The GMP build has finished." >"$(GMP_MAKE_SENTINEL)" && \
	echo "The GMP build has finished."

$(GMP_INSTALL_SENTINEL): $(GMP_MAKE_SENTINEL)
	echo && \
	echo "Installing GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GmpInstall" \
	  "GMP Install" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpInstall.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpInstall.report" \
	  $(MAKE) -C "$(GMP_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The GMP installation has finished." >"$(GMP_INSTALL_SENTINEL)" && \
	echo "The GMP installation has finished."

$(GMP_CHECK_SENTINEL): $(GMP_MAKE_SENTINEL)
	echo && \
	echo "Checking GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GmpCheck" \
	  "GMP Check" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpCheck.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpCheck.report" \
	  $(MAKE) -C "$(GMP_OBJ_DIR)" check && \
	echo "The GMP check has finished." >"$(GMP_CHECK_SENTINEL)" && \
	echo "The GMP check has finished."


# ----------------- Build MPFR -----------------

$(MPFR_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(MPFR_TAR_FILE) ..." && \
	if [ -d "$(MPFR_SRC_DIR)" ]; then rm -rf -- "$(MPFR_SRC_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(MPFR_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking MPFR finished." >"$(MPFR_UNTAR_SENTINEL)" && \
	echo "Unpacking MPFR finished."

$(MPFR_MAKEFILE): $(MPFR_UNTAR_SENTINEL)  $(GMP_INSTALL_SENTINEL)
	echo && \
	echo "Configuring MPFR from $(MPFR_SRC_DIR)/ to $(MPFR_OBJ_DIR)/" && \
	if [ -d "$(MPFR_OBJ_DIR)" ]; then rm -rf -- "$(MPFR_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(MPFR_OBJ_DIR)" && \
	pushd "$(MPFR_OBJ_DIR)" >/dev/null && \
	echo "Help text from the 'configure' script:" && \
	$(MPFR_SRC_DIR)/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrConfigHelp.txt" && \
	echo && \
	echo "Configuring:" && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpfrConfigure" \
	  "MPFR Configure" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrConfigure.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrConfigure.report" \
	  $(MPFR_SRC_DIR)/configure \
	    $(CONFIG_CACHE_OPTION)  \
	    $(HOST_FLAGS_WITH_OPT_AND_LTO) \
	    $(FLAGS_TO_BUILD_GMP_ETC_AS_STATIC_ONLY_LIBS) \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --with-gmp="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The MPFR configuration has finished."

$(MPFR_MAKE_SENTINEL): $(MPFR_MAKEFILE)
	echo && \
	echo "Building MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpfrMake" \
	  "MPFR Make" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrMake.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrMake.report" \
	  $(MAKE) -C "$(MPFR_OBJ_DIR)" && \
	echo "The MPFR build has finished." >"$(MPFR_MAKE_SENTINEL)" && \
	echo "The MPFR build has finished."

$(MPFR_INSTALL_SENTINEL): $(MPFR_MAKE_SENTINEL)
	echo && \
	echo "Installing MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpfrInstall" \
	  "MPFR Install" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrInstall.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrInstall.report" \
	  $(MAKE) -C "$(MPFR_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The MPFR installation has finished." >"$(MPFR_INSTALL_SENTINEL)" && \
	echo "The MPFR installation has finished."

$(MPFR_CHECK_SENTINEL): $(MPFR_MAKE_SENTINEL)
	echo && \
	echo "Checking MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpfrMake" \
	  "MPFR Make" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrMake.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrMake.report" \
	  $(MAKE) -C "$(MPFR_OBJ_DIR)" check && \
	echo "The MPFR check has finished." >"$(MPFR_CHECK_SENTINEL)" && \
	echo "The MPFR check has finished."


# ----------------- Build MPC -----------------

$(MPC_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(MPC_TAR_FILE) ..." && \
	if [ -d "$(MPC_SRC_DIR)" ]; then rm -rf -- "$(MPC_SRC_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(MPC_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking MPC finished." >"$(MPC_UNTAR_SENTINEL)" && \
	echo "Unpacking MPC finished."

$(MPC_MAKEFILE): $(MPC_UNTAR_SENTINEL)  $(GMP_INSTALL_SENTINEL)  $(MPFR_INSTALL_SENTINEL)
	echo && \
	echo "Configuring MPC from $(MPC_SRC_DIR)/ to $(MPC_OBJ_DIR)/" && \
	if [ -d "$(MPC_OBJ_DIR)" ]; then rm -rf -- "$(MPC_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(MPC_OBJ_DIR)" && \
	pushd "$(MPC_OBJ_DIR)" >/dev/null && \
	echo "Help text from the 'configure' script:" && \
	$(MPC_SRC_DIR)/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcConfigHelp.txt" && \
	echo && \
	echo "Configuring:" && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpcConfigure" \
	  "MPC Configure" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcConfigure.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcConfigure.report" \
	  $(MPC_SRC_DIR)/configure \
	    $(CONFIG_CACHE_OPTION)  \
	    $(HOST_FLAGS_WITH_OPT_AND_LTO) \
	    $(FLAGS_TO_BUILD_GMP_ETC_AS_STATIC_ONLY_LIBS) \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --with-gmp="$(CROSS_TOOLCHAIN_DIR)" \
	    --with-mpfr="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The MPC configuration has finished."

$(MPC_MAKE_SENTINEL): $(MPC_MAKEFILE)
	echo && \
	echo "Building MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpcMake" \
	  "MPC Make" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcMake.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcMake.report" \
	  $(MAKE) -C "$(MPC_OBJ_DIR)" && \
	echo "The MPC build has finished." >"$(MPC_MAKE_SENTINEL)" && \
	echo "The MPC build has finished."

$(MPC_INSTALL_SENTINEL): $(MPC_MAKE_SENTINEL)
	echo && \
	echo "Installing MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpcInstall" \
	  "MPC Install" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcInstall.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcInstall.report" \
	  $(MAKE) -C "$(MPC_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The MPC installation has finished." >"$(MPC_INSTALL_SENTINEL)" && \
	echo "The MPC installation has finished."

$(MPC_CHECK_SENTINEL): $(MPC_MAKE_SENTINEL)
	echo && \
	echo "Checking MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "MpcCheck" \
	  "MPC Check" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcCheck.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcCheck.report" \
	  $(MAKE) -C "$(MPC_OBJ_DIR)" check && \
	echo "The MPC check has finished." >"$(MPC_CHECK_SENTINEL)" && \
	echo "The MPC check has finished."


# ----------------- GCC phase 1 -----------------

$(GCC_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(GCC_TAR_FILE) ..." && \
	if [ -d "$(GCC_SRC_DIR)" ]; then rm -rf -- "$(GCC_SRC_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(GCC_TAR_FILE)" && \
	popd >/dev/null && \
	pushd "$(GCC_SRC_DIR)" >/dev/null && \
	if [ $(DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER) -ne 0 ]; then \
	  echo "Applying patch \"$(GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME)\" ..." && \
	  patch -p0 --fuzz=0 --forward <"$(GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME)"; \
	fi && \
	popd >/dev/null && \
	echo "Unpacking GCC finished." >"$(GCC_UNTAR_SENTINEL)" && \
	echo "Unpacking GCC finished."

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  $(GCC1_MAKEFILE): $(MPC_INSTALL_SENTINEL)
endif

ifeq ($(INSTALL_GCC_PHASE_1_TO_SEPARATE_DIR),1)
  $(GCC1_MAKEFILE): $(BINUTILS_INSTALL_SENTINEL_PHASE_1)
else
  $(GCC1_MAKEFILE): $(BINUTILS_INSTALL_SENTINEL)
endif

$(GCC1_MAKEFILE): $(GCC_UNTAR_SENTINEL)
	echo && \
	echo "Configuring GCC phase 1 from $(GCC_SRC_DIR)/ to $(GCC1_OBJ_DIR)/" && \
	if [ -d "$(GCC1_OBJ_DIR)" ]; then rm -rf -- "$(GCC1_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GCC1_OBJ_DIR)" && \
	pushd "$(GCC1_OBJ_DIR)" >/dev/null && \
	echo "Help text from the 'configure' script:" && \
	$(GCC_SRC_DIR)/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccConfigHelp.txt" && \
	echo && \
	echo "Configuring:" && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GccPhase1Configure" \
	  "GCC Phase 1 Configure" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Configure.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Configure.report" \
	  $(GCC_SRC_DIR)/configure \
	    --enable-languages=c \
	    --without-headers \
	    --prefix="$(PHASE_1_INSTALL_DIR)" \
	    $(HOST_FLAGS_WITHOUT_OPT) $(COMMON_GCC_OPTIONS) && \
	popd >/dev/null && \
	echo "The GCC phase 1 configuration has finished."

$(GCC1_MAKE_SENTINEL): $(GCC1_MAKEFILE)
	echo && \
	echo "Building GCC phase 1 ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GccPhase1Make" \
	  "GCC Phase 1 Make" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Make.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Make.report" \
	  $(MAKE) -C "$(GCC1_OBJ_DIR)" all-gcc && \
	echo "The GCC phase 1 build has finished." >"$(GCC1_MAKE_SENTINEL)" && \
	echo "The GCC phase 1 build has finished."

$(GCC1_INSTALL_SENTINEL): $(GCC1_MAKE_SENTINEL)
	echo && \
	echo "Installing GCC phase 1 ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GccPhase1Install" \
	  "GCC Phase 1 Install" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Install.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Install.report" \
	  $(MAKE) -C "$(GCC1_OBJ_DIR)" install-gcc && \
	echo "The GCC phase 1 installation has finished." >"$(GCC1_INSTALL_SENTINEL)" && \
	echo "The GCC phase 1 installation has finished."


# ----------------- Build Newlib -----------------

ifeq ($(TARGET_LIBC), newlib)

$(NEWLIB_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(NEWLIB_TAR_FILE) ..." && \
	if [ -d "$(NEWLIB_UNTAR_DIR)" ]; then rm -rf -- "$(NEWLIB_UNTAR_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(NEWLIB_TAR_FILE)" && \
	popd >/dev/null && \
	pushd "$(NEWLIB_SRC_DIR)" >/dev/null && \
	echo "Applying patch \"$(NEWLIB_USER_IMPLEMENTATION_OF_ASSERT_PATCH_FILENAME)\" ..." && \
	patch -p0 --fuzz=0 --forward <"$(NEWLIB_USER_IMPLEMENTATION_OF_ASSERT_PATCH_FILENAME)" && \
	if [ $(REMOVE_STRERROR_MESSAGES) -ne 0 ]; then \
	  echo "Applying patch \"$(NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME)\" ..." && \
	  patch -p0 --fuzz=0 --forward <"$(NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME)"; \
	fi && \
	popd >/dev/null && \
	echo "Unpacking Newlib finished." >"$(NEWLIB_UNTAR_SENTINEL)" && \
	echo "Unpacking Newlib finished."

$(NEWLIB_NEWLIB_MAKEFILE): $(NEWLIB_UNTAR_SENTINEL) $(GCC1_INSTALL_SENTINEL)
	echo && \
	echo "About to configure Newlib from $(NEWLIB_SRC_DIR)/ to $(NEWLIB_NEWLIB_OBJ_DIR)/" && \
	if [ -d "$(NEWLIB_NEWLIB_OBJ_DIR)" ]; then rm -rf -- "$(NEWLIB_NEWLIB_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(NEWLIB_NEWLIB_OBJ_DIR)" && \
	pushd "$(NEWLIB_NEWLIB_OBJ_DIR)" >/dev/null && \
	echo "Help text from 'configure' script for top-level Newlib dir (see further below for the newlib/ subdir):" && \
	$(NEWLIB_SRC_DIR)/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibTopLevelConfigHelp.txt" && \
	echo && \
	echo "Help text from 'configure' script for the newlib/ subdir:" && \
	$(NEWLIB_SRC_DIR)/newlib/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibNewlibConfigHelp.txt" && \
	echo && \
	echo "Configuring Newlib:" && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "NewlibConfigure" \
	    "Newlib Configure" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibConfigure.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibConfigure.report" \
	    CFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" \
	    CXXFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" \
	    $(NEWLIB_SRC_DIR)/configure \
	      $(NEWLIB_CFG_FLAGS) && \
	popd >/dev/null && \
	echo "The Newlib configuration has finished."

$(NEWLIB_NEWLIB_MAKE_SENTINEL): $(NEWLIB_NEWLIB_MAKEFILE)
	echo && \
	echo "Building Newlib ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "NewlibMake" \
	    "Newlib Make" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibMake.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibMake.report" \
	    $(MAKE) -C "$(NEWLIB_NEWLIB_OBJ_DIR)"  && \
	echo "The Newlib build has finished." >"$(NEWLIB_NEWLIB_MAKE_SENTINEL)" && \
	echo "The Newlib build has finished."

$(NEWLIB_NEWLIB_INSTALL_SENTINEL): $(NEWLIB_NEWLIB_MAKE_SENTINEL)
	echo && \
	echo "Installing Newlib ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "NewlibInstall" \
	    "Newlib Install" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibInstall.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibInstall.report" \
	    $(MAKE) -C "$(NEWLIB_NEWLIB_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The Newlib installation has finished." >"$(NEWLIB_NEWLIB_INSTALL_SENTINEL)" && \
	echo "The Newlib installation has finished."

endif


# ----------------- Build Picolibc -----------------

ifeq ($(TARGET_LIBC), picolibc)

$(PICOLIBC_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(PICOLIBC_TAR_FILE) ..." && \
	if [ -d "$(PICOLIBC_UNTAR_DIR)" ]; then rm -rf -- "$(PICOLIBC_UNTAR_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(PICOLIBC_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking Picolibc finished." >"$(PICOLIBC_UNTAR_SENTINEL)" && \
	echo "Unpacking Picolibc finished."

$(PICOLIBC_CONFIGURE_SENTINEL): $(PICOLIBC_UNTAR_SENTINEL) $(GCC1_INSTALL_SENTINEL)
	echo && \
	echo "About to configure Picolibc from $(PICOLIBC_SRC_DIR)/ to $(PICOLIBC_OBJ_DIR)/" && \
	if [ -d "$(PICOLIBC_OBJ_DIR)" ]; then rm -rf -- "$(PICOLIBC_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(PICOLIBC_OBJ_DIR)" && \
	cp -- "$(MAKEFILE_TOOLS_DIR)/$(PICOLIBC_TARGET_FLAGS_FILENAME)" "$(PICOLIBC_OBJ_DIR)/$(PICOLIBC_TARGET_FLAGS_FILENAME)" && \
	pushd "$(PICOLIBC_OBJ_DIR)" >/dev/null && \
	echo "Configuring Picolibc:" && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "PicolibcConfigure" \
	    "Picolibc Configure" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcConfigure.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcConfigure.report" \
	    meson \
	      setup \
	      --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	      $(PICOLIBC_CFG_FLAGS) \
	      --cross-file "$(PICOLIBC_OBJ_DIR)/$(PICOLIBC_TARGET_FLAGS_FILENAME)" \
	      "$(PICOLIBC_SRC_DIR)" \
	      "$(PICOLIBC_OBJ_DIR)" && \
	popd >/dev/null && \
	echo "The Picolibc installation has finished." >"$(PICOLIBC_CONFIGURE_SENTINEL)" && \
	echo "The Picolibc configuration has finished."

$(PICOLIBC_MAKE_SENTINEL): $(PICOLIBC_CONFIGURE_SENTINEL)
	echo && \
	echo "Building Picolibc ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "PicolibcMake" \
	    "Picolibc Make" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcMake.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcMake.report" \
	    meson compile --verbose  -C "$(PICOLIBC_OBJ_DIR)"  && \
	echo "The Picolibc build has finished." >"$(PICOLIBC_MAKE_SENTINEL)" && \
	echo "The Picolibc build has finished."

$(PICOLIBC_INSTALL_SENTINEL): $(PICOLIBC_MAKE_SENTINEL)
	echo && \
	echo "Installing Picolibc ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "PicolibcInstall" \
	    "Picolibc Install" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcInstall.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcInstall.report" \
	    meson install  -C "$(PICOLIBC_OBJ_DIR)"  && \
	ln --symbolic --force -- "$(PICOLIBC_LIBC_INSTALLATION_DIR)/libc.a"  "$(PICOLIBC_LIBC_INSTALLATION_DIR)/libg.a" && \
	echo "The Picolibc installation has finished." >"$(PICOLIBC_INSTALL_SENTINEL)" && \
	echo "The Picolibc installation has finished."

endif


# ----------------- GCC phase 2 -----------------

# The GCC phase 2 target needs to depend on BINUTILS_INSTALL_SENTINEL, in case we are installing
# GCC phase 1 and Binutils phase 1 into a separate directory. Remember that GCC finds
# the Binutils for the target using the '--prefix=/some/dir' configuration setting,
# so another copy of Binutils needs to be already installed at the final destination directory.
#
# Similarly, building GCC phase 2 requires GCC phase 1, so phase 1 GCC needs to be on the PATH.
#
# There might be some confusion, because both instances of Binutils are available,
# once over the '--prefix' directory, and one over PATH. But both instances are identical anyway.

ifeq ($(TARGET_LIBC), newlib)
  $(GCC2_MAKEFILE): $(NEWLIB_NEWLIB_INSTALL_SENTINEL)
endif

ifeq ($(TARGET_LIBC), picolibc)
  $(GCC2_MAKEFILE): $(PICOLIBC_INSTALL_SENTINEL)
endif

$(GCC2_MAKEFILE): $(GCC_UNTAR_SENTINEL) $(BINUTILS_INSTALL_SENTINEL)
	echo && \
	echo "Configuring GCC phase 2 from $(GCC_SRC_DIR)/ to $(GCC2_OBJ_DIR)/" && \
	if [ -d "$(GCC2_OBJ_DIR)" ]; then rm -rf -- "$(GCC2_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GCC2_OBJ_DIR)" && \
	pushd "$(GCC2_OBJ_DIR)" >/dev/null && \
	$(GCC_PHASE_2_SET_PATH_DIR) \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "GccPhase2Configure" \
	    "GCC Phase 2 Configure" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Configure.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Configure.report" \
	    $(GCC_SRC_DIR)/configure \
	      --enable-languages=c,c++ \
	      --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	      $(GCC_PHASE_2_BUILD_FLAGS) $(COMMON_GCC_OPTIONS) && \
	popd >/dev/null && \
	echo "The GCC phase 2 configuration has finished."

$(GCC2_MAKE_SENTINEL): $(GCC2_MAKEFILE)
	echo && \
	echo "Building GCC phase 2 ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(GCC_PHASE_2_SET_PATH_DIR) \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "GccPhase2Make" \
	    "GCC Phase 2 Make" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Make.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Make.report" \
	    $(MAKE) -C "$(GCC2_OBJ_DIR)" \
	      CFLAGS_FOR_TARGET="$(GCC_CFLAGS_FOR_TARGET)" \
	      CXXFLAGS_FOR_TARGET="$(GCC_CFLAGS_FOR_TARGET)" && \
	echo "The GCC phase 2 build has finished." >"$(GCC2_MAKE_SENTINEL)" && \
	echo "The GCC phase 2 build has finished."

# The "make install" step needs the PATH set because it uses Binutils tools like 'arm-none-eabi-ranlib',
# and it does not seem able to find them via the configured '--prefix' directory.

$(GCC2_INSTALL_SENTINEL): $(GCC2_MAKE_SENTINEL)
	echo && \
	echo "Installing GCC phase 2 ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "GccPhase2Install" \
	    "GCC Phase 2 Install" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Install.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Install.report" \
	    $(MAKE) -C "$(GCC2_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The GCC phase 2 installation has finished." >"$(GCC2_INSTALL_SENTINEL)" && \
	echo "The GCC phase 2 installation has finished."

# Short target name for building and installing GCC without GDB. Sometimes useful when testing this makefile.
gcc: $(GCC2_INSTALL_SENTINEL)

$(GCC2_CHECK_SENTINEL): $(GCC2_MAKE_SENTINEL)
	echo && \
	echo "Checking GCC phase 2 ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" -- \
	    "GccPhase2Install" \
	    "GCC Phase 2 Install" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Check.log" \
	    "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Check.report" \
	    $(MAKE) -C "$(GCC2_OBJ_DIR)" check \
	      CFLAGS_FOR_TARGET="$(GCC_CFLAGS_FOR_TARGET)" \
	      CXXFLAGS_FOR_TARGET="$(GCC_CFLAGS_FOR_TARGET)" && \
	echo "The GCC phase 2 check has finished." >"$(GCC2_CHECK_SENTINEL)" && \
	echo "The GCC phase 2 check has finished."


# ----------------- Build GDB -----------------

# Note that GDB runs on the host and does not need Binutils or the GCC cross-compiler.

$(GDB_UNTAR_SENTINEL): $(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL)
	echo && \
	echo "Unpacking $(GDB_TAR_FILE) ..." && \
	if [ -d "$(GDB_SRC_DIR)" ]; then rm -rf -- "$(GDB_SRC_DIR)"; fi && \
	pushd "$(CROSS_TOOLCHAIN_BUILD_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(GDB_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking GDB finished." >"$(GDB_UNTAR_SENTINEL)" && \
	echo "Unpacking GDB finished."

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  # GDB version 11.1 is the first one to require the GMP library.
  # This makefile could drop the dependency when building older GDB versions.
  $(GDB_MAKEFILE): $(GMP_INSTALL_SENTINEL) $(MPFR_INSTALL_SENTINEL)
endif

$(GDB_MAKEFILE): $(GDB_UNTAR_SENTINEL)
	echo && \
	echo "Configuring GDB from $(GDB_SRC_DIR)/ to $(GDB_OBJ_DIR)/" && \
	if [ -d "$(GDB_OBJ_DIR)" ]; then rm -rf -- "$(GDB_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GDB_OBJ_DIR)" && \
	pushd "$(GDB_OBJ_DIR)" >/dev/null && \
	echo "Help text from the 'configure' script:" && \
	$(GDB_SRC_DIR)/configure --help | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbConfigHelp.txt" && \
	echo && \
	echo "Configuring:" && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GDbConfigure" \
	  "GDB Configure" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbConfigure.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbConfigure.report" \
	  $(GDB_SRC_DIR)/configure \
	    $(GDB_BUILD_FLAGS) \
	    $(CONFIG_CACHE_OPTION)  \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --target=$(TARGET_ARCH) && \
	popd >/dev/null && \
	echo "The GDB configuration has finished."

$(GDB_MAKE_SENTINEL): $(GDB_MAKEFILE)
	echo && \
	echo "Building GDB ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GDbMake" \
	  "GDB Make" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbMake.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbMake.report" \
	  $(MAKE) -C "$(GDB_OBJ_DIR)" && \
	echo "The GDB build has finished." >"$(GDB_MAKE_SENTINEL)" && \
	echo "The GDB build has finished."

$(GDB_INSTALL_SENTINEL): $(GDB_MAKE_SENTINEL)
	echo && \
	echo "Installing GDB ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" -- \
	  "GDbInstall" \
	  "GDB Install" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbInstall.log" \
	  "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbInstall.report" \
	  $(MAKE) -C "$(GDB_OBJ_DIR)" "$(GDB_INSTALL_TARGET)" && \
	echo "The GDB installation has finished." >"$(GDB_INSTALL_SENTINEL)" && \
	echo "The GDB installation has finished."

# Short target name for building and installing GDB. Sometimes useful when testing this makefile.
gdb: $(GDB_INSTALL_SENTINEL)


# --------------- Top-level rules ---------------

.PHONY: $(TARGET_NAME_ALL) $(TARGET_NAME_HELP) $(TARGET_NAME_CLEAN)
.PHONY: $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET) $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER)
.PHONY: $(TARGET_NAME_TEST_MAKEFLAGS)
.PHONY: $(TARGET_NAME_CHECK)

.DEFAULT_GOAL := help

$(TARGET_NAME_HELP):
	@echo
	@echo "This makefile builds a GCC/Newlib toolchain for a 'bare metal' programming environment"
	@echo "for an ARM Cortex-M3 microcontroller. Other CPUs are supported, search for"
	@echo "TOOLCHAIN_TARGET_CPU in the makefile for details."
	@echo
	@echo "Before building the toolchain with this makefile, you need to do the following:"
	@echo
	@echo "1) Run this makefile for target '$(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET)' like this:"
	@echo "     make $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET)"
	@echo "   Alternatively, manually download the following files and place them in the Tarballs subdirectory:"
	@echo "     $(BINUTILS_TAR_FILE)"
	@echo "     $(GCC_TAR_FILE)"
	@if [ $(TARGET_LIBC) = "newlib" ]; then \
	 echo "     $(NEWLIB_TAR_FILE)"; \
	 fi
	@if [ $(TARGET_LIBC) = "picolibc" ]; then \
	 echo "     $(PICOLIBC_TAR_FILE)"; \
	 fi
	@echo "     $(GDB_TAR_FILE)"
	@if [ $(BUILD_GMP_MPFR_MPC) -ne 0 ]; then \
	echo "     $(GMP_TAR_FILE)" && \
	echo "     $(MPFR_TAR_FILE)" && \
	echo "     $(MPC_TAR_FILE)" ; \
	fi
	@echo "   A third option is to use target '$(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER)'"
	@echo "   together with variable PATH_TO_TARBALLS_ON_FILE_SERVER."
	@echo
	@echo "2) Think about a directory of your choice for variable CROSS_TOOLCHAIN_DIR where"
	@echo "   the toolchain will be installed. For example: CROSS_TOOLCHAIN_DIR=\"\$$HOME/my-new-toolchain-14-bin\""
	@echo "   You will probably build several toolchains, so inserting a number is probably a good idea."
	@echo "   You should start with a clean installation directory, or you may end up with a problematic mixture of"
	@echo "   old and new files, for different targets, or built with different flags."
	@echo
	@echo "3) Consider passing variable CROSS_TOOLCHAIN_BUILD_DIR with some directory of your choice where"
	@echo "   all source and object files will be unpacked or generated during the toolchain build process."
	@echo "   For example: CROSS_TOOLCHAIN_BUILD_DIR=\"\$$HOME/my-new-toolchain-14-build\""
	@echo "   By default, these build files are placed in a subdirectory called \"Tmp\". That name is"
	@echo "   intuitive enough. I normally have such \"Tmp\" directories listed in my .gitignore files,"
	@echo "   and I tend to skip anything called \"Tmp\" when doing recursive greps."
	@echo "   The build directory can be discarded after the toolchain has been installed to the"
	@echo "   CROSS_TOOLCHAIN_DIR directory you chose further above. However, if you keep it, you will be"
	@echo "   able to step into the C runtime library and so on when debugging your software with GDB."
	@echo "   If you will be discarding it at the end, and you have memory to spare, placing it"
	@echo "   on a RAM disk like tmpfs will speed up building the toolchain and discarding the"
	@echo "   build directory at the end considerably."
	@echo "   You should start with a clean build directory, or you may end up with a problematic mixture of"
	@echo "   old and new files, for different targets, or built with different flags."
	@echo
	@echo "4) Consider setting variable ENABLE_DEBUG_TOOLCHAIN to '1' in order to build a debug toolchain."
	@echo "   This enables debug code in Newlib's malloc implementation, for example."
	@echo "   Note that your final binary will be bigger and perform more slowly, so you should use a normal"
	@echo "   (non-debug) toolchain when building a public release of your software."
	@echo "   You can compile debug builds of your software with a non-debug toolchain, but the libraries"
	@echo "   that the toolchain provides (such as Newlib) will be linked in as non-debug versions."
	@echo
	@echo "5) Install any packages needed to build GCC and GDB, like a C compiler and ELF libraries."
	@echo "   The 'devel' versions of those packages are probably needed. You will normally"
	@echo "   find such libraries in your Linux distribution's repository. Note that this makefile"
	@echo "   builds GMP, MPFR and MPC itself by default."
	@echo "   Consult GCC's and GDB's documentation for details."
	@echo "   On Ubuntu/Debian systems, installing package 'build-essential' gets you a long way."
	@echo "   Package 'libsource-highlight-dev' provides syntax highlighting in GDB."
	@echo "   On Windows/Cygwin, install these packages: gcc-core gcc-g++ automake make curl patch libtool"
	@echo
	@echo "6) Run this makefile for target '$(TARGET_NAME_ALL)'. The recommended command is:"
	@echo
	@echo "   # Remember to delete any old build and installation directories first."
	@echo
	@echo "   make CROSS_TOOLCHAIN_DIR=\"\$$HOME/my-new-toolchain-14-bin\" \\"
	@echo "        CROSS_TOOLCHAIN_BUILD_DIR=\"\$$HOME/my-new-toolchain-14-build\" \\"
	@echo "        --no-builtin-variables \\"
	@echo "        -j \"\$$(( \$$(getconf _NPROCESSORS_ONLN) + 1 ))\" --output-sync=recurse \\"
	@echo "        $(TARGET_NAME_ALL)"
	@echo
	@echo "7) If you are worried whether the generated toolchain is reliable,"
	@echo "   run target '$(TARGET_NAME_CHECK)' at the end."
	@echo "   You will probably need to install tools like DejaGnu, Tcl, and Expect beforehand."
	@echo "   Full testing is not implemented yet. In order to do it properly, you would need a"
	@echo "   virtual machine for an ARM CPU etc. At the moment, only some components are tested"
	@echo "   with this target."
	@echo


TARGET_ALL_SENTINEL := $(CROSS_TOOLCHAIN_BUILD_DIR)/$(SENTINEL_FILENAME_PREFIX)TargetAllSentinel

$(TARGET_ALL_SENTINEL): $(GDB_INSTALL_SENTINEL)  $(GCC2_INSTALL_SENTINEL)
	@echo && \
	echo "Toolchain installed in \"$(CROSS_TOOLCHAIN_DIR)\"." && \
	echo "Toolchain installed in \"$(CROSS_TOOLCHAIN_DIR)\"." >"$(TARGET_ALL_SENTINEL)" && \
	if [ $(SHOULD_WARN_ABOUT_REBUILDING_SOFTWARE) -ne 0 ]; then \
	echo "WARNING: After a toolchain change you should rebuild all software built with it from scratch." ; \
	fi

$(TARGET_NAME_ALL): $(TARGET_ALL_SENTINEL)


# This 'clean' rule does not delete the toolchain bin directory (variable CROSS_TOOLCHAIN_DIR),
# the user has to delete it manually. I'm not sure whether that is a good idea or not,
# but a toolchain takes long to build and the user may want to save it in case the new one
# does not work correctly.
$(TARGET_NAME_CLEAN):
	@echo && \
	echo "Deleting directory \"$(CROSS_TOOLCHAIN_BUILD_DIR)\"..." && \
	rm -rf -- "$(CROSS_TOOLCHAIN_BUILD_DIR)" && \
	echo "Finished. You may want to delete the toolchain installation directory you specified originally with variable CROSS_TOOLCHAIN_DIR."


GNU_MIRROR_BASE_URL := http://ftpmirror.gnu.org

DOWNLOAD_TARBALL_TOOL_PATH := $(MAKEFILE_TOOLS_DIR)/DownloadTarball.sh

# An alternative to this target could be script contrib/download_prerequisites in the GCC sources.
$(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET):
	@echo
	mkdir --parents -- "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/binutils/$(BINUTILS_TAR_FILE)"           "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/gcc/gcc-$(GCC_VERSION)/$(GCC_TAR_FILE)"  "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/gdb/$(GDB_TAR_FILE)"                     "$(TARBALLS_DOWNLOAD_DIR)"
	if [ $(TARGET_LIBC) = "newlib" ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "ftp://sourceware.org/pub/newlib/$(NEWLIB_TAR_FILE)"           "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	if [ $(TARGET_LIBC) = "picolibc" ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "https://github.com/picolibc/picolibc/releases/download/$(PICOLIBC_VERSION)/$(PICOLIBC_TAR_FILE)"  "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	if [ $(BUILD_GMP_MPFR_MPC) -ne 0 ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/gmp/$(GMP_TAR_FILE)"    "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/mpfr/$(MPFR_TAR_FILE)"  "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/mpc/$(MPC_TAR_FILE)"    "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	@echo "Finished downloading tarballs from the Internet."

$(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER):
	@echo
	mkdir --parents -- "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(BINUTILS_TAR_FILE)" "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(GCC_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(GDB_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)"
	if [ $(TARGET_LIBC) = "newlib" ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(NEWLIB_TAR_FILE)"   "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	if [ $(TARGET_LIBC) = "picolibc" ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(PICOLIBC_TAR_FILE)" "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	if [ $(BUILD_GMP_MPFR_MPC) -ne 0 ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(GMP_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(MPFR_TAR_FILE)"     "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(MPC_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	@echo "Finished downloading tarballs from the file server."

$(TARGET_NAME_TEST_MAKEFLAGS):
	@$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && echo "MAKEFLAGS passed in the environment: $$MAKEFLAGS"

$(TARGET_NAME_CHECK): $(BINUTILS_CHECK_SENTINEL)

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  $(TARGET_NAME_CHECK): $(GMP_CHECK_SENTINEL) $(MPFR_CHECK_SENTINEL) $(MPC_CHECK_SENTINEL)
endif

# We cannot run the GCC checks on the host PC:
# $(TARGET_NAME_CHECK): $(GCC2_CHECK_SENTINEL)

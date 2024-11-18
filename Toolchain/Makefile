
# Run "make help" for information about how to use this makefile.
#
# Copyright (c) 2013-2024 - R. Diez - Licensed under the GNU AGPLv3.


# ------- Standard Configuration -------

THIS_MAKEFILE_DIR := $(shell readlink --verbose --canonicalize -- "$(CURDIR)")

MAKEFILE_TOOLS_DIR        := $(THIS_MAKEFILE_DIR)/Tools
MAKEFILE_PATCHES_DIR      := $(THIS_MAKEFILE_DIR)/Patches
CROSS_TOOLCHAIN_BUILD_DIR := $(THIS_MAKEFILE_DIR)/Tmp
TARBALLS_DOWNLOAD_DIR     := $(THIS_MAKEFILE_DIR)/Tarballs

include $(MAKEFILE_TOOLS_DIR)/MakefileCommon.mk

RUN_AND_REPORT_TOOL_PATH := $(MAKEFILE_TOOLS_DIR)/RunAndReport.sh


# Variable CROSS_TOOLCHAIN_BUILD_DIR is often overriden on the 'make' command line,
# so checking just THIS_MAKEFILE_DIR would not be enough.
$(call check_variable_non_empty_and_contains_no_whitespace,CROSS_TOOLCHAIN_BUILD_DIR)


TARGET_NAME_ALL   := all
TARGET_NAME_HELP  := help
TARGET_NAME_CLEAN := clean
TARGET_NAME_CHECK := check
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET    := download-tarballs-from-internet
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER := download-tarballs-from-file-server
TARGET_NAME_TEST_MAKEFLAGS_NORMAL  := test-makeflags-normal
TARGET_NAME_TEST_MAKEFLAGS_INSTALL := test-makeflags-install


# These paths are normally supplied by the user (when needed) as command-line arguments,
# so the following empty values will often be overriden from outside:
CROSS_TOOLCHAIN_DIR:=
PATH_TO_TARBALLS_ON_FILE_SERVER:=
$(call poison_variable_if_empty_or_contains_whitespace,CROSS_TOOLCHAIN_DIR)
$(call poison_variable_if_empty_or_contains_whitespace,PATH_TO_TARBALLS_ON_FILE_SERVER)


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
#
# If you want to use Picolibc, you need Meson version 0.56 or later.

VERSION_SET := VersionSet15

ifeq ($(VERSION_SET),VersionSet7)

  BINUTILS_VERSION := 2.36.1
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 10.3.0
  NEWLIB_VERSION := 4.1.0
  PICOLIBC_VERSION := picolibc-not-supported-yet
  GDB_VERSION := 10.2

else ifeq ($(VERSION_SET),VersionSet8)

  BINUTILS_VERSION := 2.37
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 10.3.0
  NEWLIB_VERSION := 4.1.0
  PICOLIBC_VERSION := picolibc-not-supported-yet
  GDB_VERSION := 11.1

else ifeq ($(VERSION_SET),VersionSet9)

  BINUTILS_VERSION := 2.37
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 11.2.0
  NEWLIB_VERSION := 4.1.0
  PICOLIBC_VERSION := picolibc-not-supported-yet
  GDB_VERSION := 11.2

else ifeq ($(VERSION_SET),VersionSet10)

  BINUTILS_VERSION := 2.38
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 11.2.0
  NEWLIB_VERSION := 4.1.0
  PICOLIBC_VERSION := 1.8.2
  GDB_VERSION := 12.1

else ifeq ($(VERSION_SET),VersionSet11)

  BINUTILS_VERSION := 2.39
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.1.0
  MPC_VERSION := 1.2.1
  GCC_VERSION := 12.2.0
  NEWLIB_VERSION := 4.1.0
  PICOLIBC_VERSION := 1.8.2
  GDB_VERSION := 12.1

else ifeq ($(VERSION_SET),VersionSet12)

  BINUTILS_VERSION := 2.40
  GMP_VERSION := 6.2.1
  MPFR_VERSION := 4.2.0
  MPC_VERSION := 1.3.1
  GCC_VERSION := 12.3.0
  NEWLIB_VERSION := 4.3.0.20230120
  PICOLIBC_VERSION := 1.8.2
  GDB_VERSION := 13.2

else ifeq ($(VERSION_SET),VersionSet13)

  BINUTILS_VERSION := 2.41
  GMP_VERSION := 6.3.0
  MPFR_VERSION := 4.2.1
  MPC_VERSION := 1.3.1
  GCC_VERSION := 13.2.0
  NEWLIB_VERSION := 4.3.0.20230120
  PICOLIBC_VERSION := 1.8.5
  GDB_VERSION := 13.2

else ifeq ($(VERSION_SET),VersionSet14)

  BINUTILS_VERSION := 2.42
  GMP_VERSION := 6.3.0
  MPFR_VERSION := 4.2.1
  MPC_VERSION := 1.3.1
  GCC_VERSION := 13.3.0
  NEWLIB_VERSION := 4.4.0.20231231
  PICOLIBC_VERSION := 1.8.6
  GDB_VERSION := 15.1

else ifeq ($(VERSION_SET),VersionSet15)

  BINUTILS_VERSION := 2.43.1
  GMP_VERSION := 6.3.0
  MPFR_VERSION := 4.2.1
  MPC_VERSION := 1.3.1
  GCC_VERSION := 14.2.0
  NEWLIB_VERSION := 4.4.0.20231231
  PICOLIBC_VERSION := 1.8.8
  GDB_VERSION := 15.2

else
  $(error Invalid configuration set "$(VERSION_SET)")
endif


TARGET_LIBC := newlib

ifneq "$(TARGET_LIBC)" "newlib"
  ifneq "$(TARGET_LIBC)" "picolibc"
    $(error Invalid value of TARGET_LIBC: $(TARGET_LIBC))
  endif
endif


IS_GCC_10_X  := $(filter 10.%,$(GCC_VERSION))
IS_GCC_11_X  := $(filter 11.%,$(GCC_VERSION))
IS_GCC_12_X  := $(filter 12.%,$(GCC_VERSION))
IS_GCC_13_X  := $(filter 13.%,$(GCC_VERSION))
IS_GCC_14_X  := $(filter 14.%,$(GCC_VERSION))

ifeq "$(or $(IS_GCC_10_X), $(IS_GCC_11_X), $(IS_GCC_12_X), $(IS_GCC_13_X), $(IS_GCC_14_X) )" ""
  $(error Unsupported GCC version)
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
HF_LTO := -flto=auto


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

PATH_DIR = $(CROSS_TOOLCHAIN_DIR)/bin


# ------- MAKEFLAGS filtering -------

# If you are not calling recursive makefiles, but running other unrelated makefiles, you do not normally
# want to pass the MAKEFLAGS you got. For example, the top-level makefile is often called with options
# '--no-builtin-variables' and '--warn-undefined-variables', which could break other makefiles.
# Therefore, we want to clean MAKEFLAGS beforehand.
#
# However, we still want to pass on those flags related to GNU Make's job server. They look like this:
# - In GNU Make version 3.81:  MAKEFLAGS: --jobserver-fds=3,4 -j -- SOMEVAR=SOMEVALUE ...
# - In GNU Make version 4.2.1: MAKEFLAGS: -j3 --jobserver-auth=3,4 -Orecurse -- SOMEVAR=SOMEVALUE ...
# - In GNU Make version 4.4.1: MAKEFLAGS: -j3 --jobserver-auth=fifo:/tmp/GMfifo2186190 -Orecurse -- SOMEVAR=SOMEVALUE ...
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
# GNU Make has an exception for MAKEFLAGS: if it is defined in the environment,
# it takes precedence over MAKEFLAGS specified in the makefile.
# However, we will be overriding this variable in the environment when running rules.
# This may surprise the user, but I haven't found any other way yet to deal
# with the flags and the job server. The safest bet is to avoid setting MAKEFLAGS
# in the enviroment when using this makefile.
# I tried to check with $(origin MAKEFLAGS) whether MAKEFLAGS was defined in the environment,
# but the origin function always returns 'file' for this variable, at least with GNU Make 4.4.1 .
#
# Note that we cannot use ':=' kind of assignments below, because GNU Make adds
# options like '--jobserver-auth=' to MAKEFLAGS later on, when executing a rule.
# Use target $(TARGET_NAME_TEST_MAKEFLAGS_NORMAL) to test this logic.

EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS = $(strip $(filter -j%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-fds=%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-auth=%,$(MAKEFLAGS)) \
                                                $(filter -O%,$(MAKEFLAGS)))

EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS = export MAKEFLAGS="$(EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS)"

# In the past, when we only had conventional spinning disks, it was considered a bad idea to run
# makefile 'install' targets in parallel. However, if you have a modern SSD, or if you are installing
# to a high-latency network drive, a parallel installation may actually be faster.
#
# The trouble is, the number of parallel jobs is usually adjusted according to the number of CPUs,
# and is not suitable for disk or network activities. GNU Make's job server can only
# coordinate based on a single limit, as it has no concept of job type. We cannot just set
# a fixed number of jobs for the install targets, because many of them may run in parallel,
# so we would run the risk of not honouring the intended limit.
# Therefore, just disable parallel execution for makefile 'install' targets.

CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS := export MAKEFLAGS=""


# ------- Build directory definitions -------

CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL   := $(CROSS_TOOLCHAIN_BUILD_DIR)/$(call sentinel_filename,BuildDirCreation)
CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES  := $(CROSS_TOOLCHAIN_BUILD_DIR)/ToolchainBuilder-LogFiles
CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES := $(CROSS_TOOLCHAIN_BUILD_DIR)/ToolchainBuilder-HelpFiles


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
COMMON_CFLAGS_FOR_TARGET += -fno-use-cxa-atexit

COMMON_CFLAGS_FOR_LIBC :=

# GCC options '-flto -ffat-lto-objects' makes static libraries optimal for both LTO and non-LTO builds.
# In a small test firmware that barely uses any libc routines, I saw a reduction in size of around 200 bytes,
# so these LTO settings do have an effect.
#
# You would normally place the LTO flags in COMMON_CFLAGS_FOR_TARGET, in order to build GCC's libstdc++
# in the same way, but I started just by building Newlib and Picolibc with those flags like this:
#
#   COMMON_CFLAGS_FOR_LIBC := -flto -ffat-lto-objects
#
# However, as soon as the firmware grew a little, I started getting "undefined reference" linker errors for
# 'toupper', 'vsnprintf', 'strchr' and so on. I was testing with GCC 11.2.
#
# I suspect these errors have to do with the lack of "-fno-builtin", because adding it to the project often
# fixed the problems. But not always. Both Newlib and Picolibc were built with -fno-builtin too.
# This happened mostly with release builds, but sometimes with debug builds too, which are not actually using LTO,
# so they shouldn't have this issue. It is not clear what is wrong.
# This problem is probably described in the following bug report:
#   Building with -flto in CFLAGS_FOR_TARGET / CXXFLAGS_FOR_TARGET
#   https://gcc.gnu.org/bugzilla/show_bug.cgi?id=60160
#
# I then tried building GCC's libstdc++ too with the same LTO flags like this:
#
#   COMMON_CFLAGS_FOR_TARGET += -flto -ffat-lto-objects
#
# But I got "undefined reference" linker errors too for 'malloc', 'free', 'abort'
# and a bunch of weird C++ symbols like 'unwind_phase2', 'class_type_info.cc.825a3992' or 'eh_arm.cc.87ac54f2'.

# Newlib's standard assert() implementation ends up calling fiprintf(), which pulls in loads of C runtime I/O functions,
# and we don't want that in our memory-constrained embedded environment.
COMMON_CFLAGS_FOR_LIBC += -DHAVE_ASSERT_FUNC

# Newlib's standard abort() implementation calls raise(), which pulls some signal-handling code
# that is useless in our embedded environment. GCC's C++ exception handling support library calls abort(),
# so we should provide our own space-saving implementation.
COMMON_CFLAGS_FOR_LIBC += -DABORT_PROVIDED


# ------- Binutils configuration -------

BINUTILS_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/binutils-$(BINUTILS_VERSION)
BINUTILS_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/binutils-$(BINUTILS_VERSION)-obj
BINUTILS_TAR_FILE := binutils-$(BINUTILS_VERSION).tar.xz

# Option --enable-plugins is necessary for the linker to understand the '--plugin'
# command-line option that the GCC driver passes when using LTO.
BINUTILS_CONFIGURE_OPTIONS := --enable-plugins

# We are not using the Gold linker yet.
#   BINUTILS_CONFIGURE_OPTIONS += --enable-gold=yes

BINUTILS_UNTAR_SENTINEL := $(BINUTILS_SRC_DIR)/$(call sentinel_filename,BinutilsDecompress)
BINUTILS_HELP_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(call sentinel_filename,BinutilsHelp)
BINUTILS_MAKEFILE                 := $(BINUTILS_OBJ_DIR)/Makefile
BINUTILS_MAKE_SENTINEL            := $(BINUTILS_OBJ_DIR)/$(call sentinel_filename,BinutilsMake)
BINUTILS_INSTALL_SENTINEL         := $(BINUTILS_OBJ_DIR)/$(call sentinel_filename,BinutilsInstall)
BINUTILS_INSTALL_SENTINEL_PHASE_1 := $(BINUTILS_OBJ_DIR)/$(call sentinel_filename,BinutilsInstallPhase1)
BINUTILS_CHECK_SENTINEL           := $(BINUTILS_OBJ_DIR)/$(call sentinel_filename,BinutilsCheck)


# ------- GMP lib configuration -------

GMP_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gmp-$(GMP_VERSION)
GMP_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gmp-$(GMP_VERSION)-obj
GMP_TAR_FILE := gmp-$(GMP_VERSION).tar.bz2

GMP_UNTAR_SENTINEL := $(GMP_SRC_DIR)/$(call sentinel_filename,GmpDecompress)
GMP_HELP_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(call sentinel_filename,GmpHelp)
GMP_MAKEFILE         := $(GMP_OBJ_DIR)/Makefile
GMP_MAKE_SENTINEL    := $(GMP_OBJ_DIR)/$(call sentinel_filename,GmpMake)
GMP_INSTALL_SENTINEL := $(GMP_OBJ_DIR)/$(call sentinel_filename,GmpInstall)
GMP_CHECK_SENTINEL   := $(GMP_OBJ_DIR)/$(call sentinel_filename,GmpCheck)


# According to GMP's documentation, when building for Windows:
#  "Static and DLL libraries can't both be built, since certain export directives in gmp.h must be different."
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

MPFR_UNTAR_SENTINEL := $(MPFR_SRC_DIR)/$(call sentinel_filename,MpfrDecompress)
MPFR_HELP_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(call sentinel_filename,MpfrHelp)
MPFR_MAKEFILE         := $(MPFR_OBJ_DIR)/Makefile
MPFR_MAKE_SENTINEL    := $(MPFR_OBJ_DIR)/$(call sentinel_filename,MpfrMake)
MPFR_INSTALL_SENTINEL := $(MPFR_OBJ_DIR)/$(call sentinel_filename,MpfrInstall)
MPFR_CHECK_SENTINEL   := $(MPFR_OBJ_DIR)/$(call sentinel_filename,MpfrCheck)


# ------- MPC lib configuration -------
#
# This libray can be downloaded from http://www.multiprecision.org/
# Version 1.1.0 has been released in the meantime, so that it builds against MPFR 4.0.x .

MPC_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/mpc-$(MPC_VERSION)
MPC_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/mpc-$(MPC_VERSION)-obj
MPC_TAR_FILE := mpc-$(MPC_VERSION).tar.gz

MPC_UNTAR_SENTINEL := $(MPC_SRC_DIR)/$(call sentinel_filename,MpcDecompress)
MPC_HELP_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(call sentinel_filename,MpcHelp)
MPC_MAKEFILE         := $(MPC_OBJ_DIR)/Makefile
MPC_MAKE_SENTINEL    := $(MPC_OBJ_DIR)/$(call sentinel_filename,MpcMake)
MPC_INSTALL_SENTINEL := $(MPC_OBJ_DIR)/$(call sentinel_filename,MpcInstall)
MPC_CHECK_SENTINEL   := $(MPC_OBJ_DIR)/$(call sentinel_filename,MpcCheck)


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

ifeq ($(TARGET_LIBC), picolibc)

  # Option "--enable-cstdio=stdio_pure" tells libstdc++-v3 to not use 'fdopen'
  # and only use FILE* for C++ stream I/O.
  # That is the only method that Picolibc's tinystdio supports.
  # This option is only available from GCC version 11 onwards.
  # Without this flag, libstdc++ optimises performance with custom code
  # for both glibc and Newlib, directly manipulating private fields
  # within the FILE struct etc.
  # In any case, you should not really be using file-based I/O in a bare-metal application.
  GCC_PHASE_2_BUILD_FLAGS += --enable-cstdio=stdio_pure

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
GCC_UNTAR_SENTINEL := $(GCC_SRC_DIR)/$(call sentinel_filename,GccDecompress)
GCC_HELP_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(call sentinel_filename,GccHelp)

GCC1_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)-obj-phase1
GCC1_MAKEFILE         := $(GCC1_OBJ_DIR)/Makefile
GCC1_MAKE_SENTINEL    := $(GCC1_OBJ_DIR)/$(call sentinel_filename,GccPhase1Make)
GCC1_INSTALL_SENTINEL := $(GCC1_OBJ_DIR)/$(call sentinel_filename,GccPhase1Install)

GCC2_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)-obj-phase2
GCC2_MAKEFILE         := $(GCC2_OBJ_DIR)/Makefile
GCC2_MAKE_SENTINEL    := $(GCC2_OBJ_DIR)/$(call sentinel_filename,GccPhase2Make)
GCC2_INSTALL_SENTINEL := $(GCC2_OBJ_DIR)/$(call sentinel_filename,GccPhase2Install)
GCC2_CHECK_SENTINEL   := $(GCC2_OBJ_DIR)/$(call sentinel_filename,GccPhase2Check)

GCC_C_AND_CXX_FLAGS_FOR_TARGET := $(COMMON_CFLAGS_FOR_TARGET)
# GCC_C_AND_CXX_FLAGS_FOR_TARGET += -H  # Print the name of each header file included, useful during development of this makefile.

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

GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME :=

ifeq ($(DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER),1)

  ifneq "$(or $(IS_GCC_10_X), $(IS_GCC_11_X), $(IS_GCC_12_X) )" ""
    # The patch for GCC version 5.1.0 works up to GCC version 12.x .
    GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME := GccDisableCppExceptionEmergencyBuffer-GCC-5.3.0.patch
  else ifneq "$(or $(IS_GCC_13_X), $(IS_GCC_14_X) )" ""
    # Without --enable-libstdcxx-static-eh-pool, libstdc++ calls getenv() on start-up to query
    # an eventual environment variable named GLIBCXX_TUNABLES, in case the configured pool size
    # is overridden to a non-zero amount and the pool must be allocated with malloc().
    COMMON_GCC_OPTIONS += --enable-libstdcxx-static-eh-pool --with-libstdcxx-eh-pool-obj-count=0
  endif

endif

COMMON_GCC_OPTIONS += --with-gnu-ld --with-gnu-as

# It is not clearly documented what --enable-lto does.
# By looking at GCC's configure.ac, it looks like it enables LTO support by building the LTO plug-ins
# for the linker. This option is enabled by default on most interesting platforms.
# We could probably disable it and save some build time for the GCC phase 1,
# but we may want to build Newlib with LTO support in the future.
COMMON_GCC_OPTIONS += --enable-lto


# For more information about the following patch, see:
#  Bug 107500 - Useless atexit entry for ~constant_init in eh_globals.cc
#  https://gcc.gnu.org/bugzilla/show_bug.cgi?id=107500
# This patch should no longer be necessary in GCC version 12.4 .
GCC_12_EH_GLOBALS_ATEXIT_PATCH_FILENAME := Gcc12EhGlobalsAtexit.patch


# ------- Newlib configuration -------

NEWLIB_TAR_FILE := newlib-$(NEWLIB_VERSION).tar.gz

ifeq ($(TARGET_LIBC), newlib)

  NEWLIB_UNTAR_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/newlib-$(NEWLIB_VERSION)
  NEWLIB_SRC_DIR := $(NEWLIB_UNTAR_DIR)
  NEWLIB_HELP_DIR := $(NEWLIB_SRC_DIR)/newlib
  NEWLIB_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/newlib-$(NEWLIB_VERSION)-obj

  NEWLIB_UNTAR_SENTINEL := $(NEWLIB_SRC_DIR)/$(call sentinel_filename,NewlibDecompress)
  NEWLIB_HELP_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(call sentinel_filename,NewlibHelp)
  NEWLIB_MAKEFILE         := $(NEWLIB_OBJ_DIR)/Makefile
  NEWLIB_MAKE_SENTINEL    := $(NEWLIB_OBJ_DIR)/$(call sentinel_filename,NewlibMake)
  NEWLIB_INSTALL_SENTINEL := $(NEWLIB_OBJ_DIR)/$(call sentinel_filename,NewlibInstall)

  NEWLIB_USER_IMPLEMENTATION_OF_ASSERT_PATCH_FILENAME := $(MAKEFILE_PATCHES_DIR)/NewlibUserImplementationOfAssert.patch

  # If you are using an Newlib version from before 2018-01-17, you will have to use an older version
  # of this patch stored next to the latest one.
  NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME := $(MAKEFILE_PATCHES_DIR)/NewlibRemoveStrerrorMessages.patch

  # NOTE: Newlib's switch --enable-target-optspace would add "-g -Os" to the compilation flags, but we have already done that in $(COMMON_CFLAGS_FOR_TARGET)
  NEWLIB_C_AND_CXX_FLAGS_FOR_TARGET := $(COMMON_CFLAGS_FOR_TARGET) $(COMMON_CFLAGS_FOR_LIBC)

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
    #
    # Thousands separators, as in printf( "%'d" ), are supported, but you need to set
    # 'thousands_sep' and 'grouping' first, see localeconv(). Note that setlocale() has no effect,
    # because we have disable multibyte support with --disable-newlib-mb, but modifying
    # those 2 members directly on the structure returned by localeconv() seems to work
    # (even though it is normally discouraged).
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

  # If the atexit data block is placed inside struct _reent, it will never be optimised away.
  # However, if it is global and nobody is actually registering any atexit() calls, then
  # the whole atexit block will be optimised away.
  #
  # Notes about atexit memory consumption:
  #   In Newlib, _ATEXIT_SIZE is 32 because of ANSI conformance, so each atexit block has 32 function pointers.
  #   The associated arguments for those function calls consume sizeof( struct _on_exit_args ) = 264 bytes.
  #   There is at least one, see _atexit0 and _global_atexit0.
  NEWLIB_CFG_FLAGS += --enable-newlib-global-atexit

  # We are trying to completely eliminate the need for atexit(), so we will not need dynamic allocation for it anyway.
  # We are using --enable-newlib-global-atexit above, the project is building with -fno-use-cxa-atexit
  # and the firmware is checking on start-up that there are no atexit entries,
  # so much of the atexit() support shold be optimised away in any case.
  NEWLIB_CFG_FLAGS += --disable-newlib-atexit-dynamic-alloc

  # We will be calling __libc_init_array() and __libc_fini_array() ourselves.
  # Therefore, we do not want Newlib automatically registering a call to __libc_fini_array() with atexit().
  NEWLIB_CFG_FLAGS += --disable-newlib-register-fini

  # The full version of malloc uses 'bins' and is meant to be a good all-round allocator.
  # But it starts off with an array in RAM called __malloc_av_ that weighs 1032 bytes,
  # at least for a Cortex-M3 CPU target, so it is not a good choice for very
  # constrained targets that don't do a lot of allocation.
  # The trouble is, the 'nano' version is Newlib, as of April 2021, is known to be
  # suboptimal in many normal scenarios.
  NEWLIB_CFG_FLAGS += --enable-newlib-nano-malloc

  # Libgloss can provide crt0.o and other initialisation stuff, but we would need to modify it,
  # for it does not know our particular board or environment. Modifying Libgloss is not worth the trouble,
  # we can provide our own start-up code with less effort.
  NEWLIB_CFG_FLAGS += --disable-libgloss

  # We will provide sbrk() and any other necessary board support routines (what Newlib calls 'syscalls') ourselves.
  NEWLIB_CFG_FLAGS += --disable-newlib-supplied-syscalls

  # Newlib adds to the compiler flags option '-fno-builtin', which can incur a significant performance penalty.
  # You can disable it with '--disable-newlib-fno-builtin'.
  # However, it is not clear whether that is going to cause problems when compiling the libc routines that
  # are usually replaced with such built-ins, like memset(). There are reports that leaving '-fno-builtin' out
  # cause problems with LTO too. Other people say it should be OK nowadays.
  # See this bug report for more information:
  #   memcpy implementation optimized as a call to memcpy
  #   https://gcc.gnu.org/bugzilla/show_bug.cgi?id=56888

endif


# ------- Picolibc configuration -------

PICOLIBC_TAR_FILE := picolibc-$(PICOLIBC_VERSION).tar.xz

ifeq ($(TARGET_LIBC), picolibc)

  PICOLIBC_UNTAR_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/picolibc-$(PICOLIBC_VERSION)
  PICOLIBC_SRC_DIR   := $(PICOLIBC_UNTAR_DIR)
  PICOLIBC_OBJ_DIR   := $(CROSS_TOOLCHAIN_BUILD_DIR)/picolibc-$(PICOLIBC_VERSION)-obj
  PICOLIBC_SPECS_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/picolibc-$(PICOLIBC_VERSION)-specs

  # This file will be automatically generated in the future.
  PICOLIBC_TARGET_FLAGS_FILENAME := ToolchainBuilder-cross-$(TARGET_ARCH).txt

  PICOLIBC_UNTAR_SENTINEL     := $(PICOLIBC_SRC_DIR)/$(call sentinel_filename,PicolibcDecompress)
  PICOLIBC_CONFIGURE_SENTINEL := $(PICOLIBC_OBJ_DIR)/$(call sentinel_filename,PicolibcConfigure)
  PICOLIBC_MAKE_SENTINEL      := $(PICOLIBC_OBJ_DIR)/$(call sentinel_filename,PicolibcMake)
  PICOLIBC_INSTALL_SENTINEL   := $(PICOLIBC_OBJ_DIR)/$(call sentinel_filename,PicolibcInstall)

  PICOLIBC_CFG_FLAGS =

  PICOLIBC_CFG_FLAGS += -Dincludedir="$(TARGET_ARCH)/include"
  PICOLIBC_CFG_FLAGS += -Dlibdir="$(TARGET_ARCH)/lib"

  # Note that we will be overriding these optimisation flags anyway
  # with the -Ox and -g flags in COMMON_CFLAGS_FOR_TARGET.
  # The reasons for the override is too share those flags with the Newlib counterpart.
  PICOLIBC_CFG_FLAGS += -Doptimization=s  # This is equivalent to '-Os'.
  PICOLIBC_CFG_FLAGS += -Ddebug=true      # Generate debug information, equivalent to '-g'.

  # Instead of using option --cflag=xxx with GeneratePicolibcCrossFile.sh,
  # we could use the following:
  #   PICOLIBC_CFG_FLAGS += -Dc_args=xxx
  # I have tested it with Meson 0.62.0.

  # Normally, Picolibc asks the current GCC what multilib it supports, and then it builds Picolibc for them.
  # But we are using a GCC phase 1 compiler which has no multilib support and even no libc at all.
  PICOLIBC_CFG_FLAGS += -Dmultilib=false

  # Where to place files picolibc.specs and picolibcpp.specs.
  # The directory does not need to exist, for it will be created automatically.
  # We will not be using those .specs files, but we need to specify a directory where to place them.
  # Otherwise, Picolibc will place them where GCC lives, but that would be the GCC phase 1 compiler
  # used to build Picolibc, and we will discard that GCC phase 1 compiler at the end anyway.
  # We could use 'none' to disable creating the .spec files, but you may want to look at them for reference.
  PICOLIBC_CFG_FLAGS += -Dspecsdir="$(PICOLIBC_SPECS_DIR)"

  # 'picocrt' provides crt0.o, which initialises the C environment. Disable it,
  # because our embedded application will be doing the initialisation itself.
  PICOLIBC_CFG_FLAGS += -Dpicocrt=false

  # 'picolib' provides startup helpers like the ARM interrupt vector, TLS support and sbrk.
  # Our embedded application will provide its own interrupt vector, its own sbrk,
  # and has no threading, so it does not need TLS.
  PICOLIBC_CFG_FLAGS += -Dpicolib=false

  # The tinystdio library has a much smaller memory footprint than Newlib's stdio library.
  #
  # The main drawback is a reduced I/O performance, but a bare-metal application will probably not use
  # much file-based I/O or C++ stream I/O, if at all.
  # However, expect a drastic performance drop in routines like sprintf() too, even if they apparently
  # do not use any FILE-based I/O. Internally, those routines use a virtual, in-memory FILE,
  # and tinystdio processes data on a byte-by-byte basis (one function call per byte),
  # at least as of Picolib 1.7.6 (March 2022).
  #
  # Another shortcoming is the lack of locale support, so routines like strfmon() are not really useful anymore.
  # There aren't even thousands separators as in printf( "%'d" ), as of Picolib 1.7.6 (March 2022).
  PICOLIBC_CFG_FLAGS += -Dtinystdio=true

  # Our bare-metal firmware does not use anything like fopen/fdopen.
  # Picolibc version 1.8.2 has a bug and does not build with posix-io=false .
  ifneq "$(PICOLIBC_VERSION)" "1.8.2"
    PICOLIBC_CFG_FLAGS += -Dposix-io=false
  endif

  # Enable C99 support in I/O functions like printf/scanf.
  # Note that tinystdio does not support thousands separators, as in printf( "%'d" ),
  # as of Picolib 1.7.6 (March 2022).
  PICOLIBC_CFG_FLAGS += -Dio-c99-formats=true

  # Disable floating-point support in printf and scanf.
  PICOLIBC_CFG_FLAGS += -Dformat-default=integer

  # Enable long long (normally 64-bits) type support in I/O functions like printf/scanf.
  PICOLIBC_CFG_FLAGS += -Dio-long-long=true

  PICOLIBC_CFG_FLAGS += -Dnewlib-multithread=false

  # You can actually enable newlib-retargetable-locking even if there is no threading support,
  # but then your firmware has to provide routines like __retarget_lock_acquire_recursive().
  PICOLIBC_CFG_FLAGS += -Dnewlib-retargetable-locking=false

  PICOLIBC_CFG_FLAGS += -Dthread-local-storage=false

  # We haven't got any threading that errno should worry about.
  PICOLIBC_CFG_FLAGS += -Dnewlib-global-errno=true

  # Setting 'atomic-ungetc' makes getc/ungetc re-entrant using atomic operations.
  # But we do not have threading, and we will not be using FILE routines anyway.
  PICOLIBC_CFG_FLAGS += -Datomic-ungetc=false

  # See --enable-newlib-nano-malloc in the Newlib section for more information.
  PICOLIBC_CFG_FLAGS += -Dnewlib-nano-malloc=true

  # Semihosting is useful when running under a debugger or a simulator.
  # Picolibc offers semihosting support, but this project has its own simplified semihost routines.
  PICOLIBC_CFG_FLAGS += -Dsemihost=false

  # We will not be using any iconv support.
  PICOLIBC_CFG_FLAGS += -Dnewlib-iconv-encodings=none

  # We will be using these tables defined in the linker script file:
  #   __preinit_array_start/__preinit_array_end  (there is no postfini array)
  #   __init_array_start / __init_array_end
  #   __fini_array_start / __fini_array_end
  # Rather than using those tables directly, we will be calling __libc_init_array() and __libc_fini_array().
  # This option makes __libc_init_array() and __libc_fini_array() available in Picolibc.
  # Newlib auto-detects this setting by looking in the compilation result for a section header called INIT_ARRAY
  PICOLIBC_CFG_FLAGS += -Dnewlib-initfini-array=true

  # _init() and _fini() are special functions generated dynamically during linking and associated with
  # sections .init and .fini defined in the linker script file.
  # We are not using _init() and _fini(), but only the tables defined by __init_array_start etc.
  # _init() and _fini() are deprecated anyway. The linker script file checks that these routines are (almost) empty.
  PICOLIBC_CFG_FLAGS += -Dnewlib-initfini=false

  # We will be calling __libc_init_array() and __libc_fini_array() ourselves.
  # Therefore, we do not want Picolibc automatically registering a call to __libc_fini_array() with atexit().
  PICOLIBC_CFG_FLAGS += -Dnewlib-register-fini=false

  # We are trying to completely eliminate the need for atexit(), so we will not need dynamic allocation for it anyway.
  # We are using newlib-global-atexit=true below, the project is building with -fno-use-cxa-atexit
  # and the firmware is checking on start-up that there are no atexit entries,
  # so much of the atexit() support shold be optimised away in any case.
  PICOLIBC_CFG_FLAGS += -Dnewlib-atexit-dynamic-alloc=false

  # Without thread support, this option does not really matter. Picolibc does not have a struct _reent,
  # so the atexit() data will be global anyway.
  PICOLIBC_CFG_FLAGS += -Dnewlib-global-atexit=true

  # The Meson build system documents all supported CPU family names.
  PICOLIBC_CPU_FAMILY := arm
  PICOLIBC_CPU_ENDIANNESS := little

  PICOLIBC_C_FLAGS_FOR_TARGET := $(COMMON_CFLAGS_FOR_TARGET) $(COMMON_CFLAGS_FOR_LIBC)

  # Meson unconditionally adds compiler flag -D_FILE_OFFSET_BITS=64,
  # which is wrong for our bare-meta, 32-bit platform
  # This is a work-around to cancel it.
  # I do not think we are using this constant, but who knows.
  PICOLIBC_C_FLAGS_FOR_TARGET += -U_FILE_OFFSET_BITS

  # Unlike Newlib, the Picolibc build system automatically adds a variety of compiler flags.
  # This is unfortunately not documented. Some flags are added only if the compiler supports them.
  # Furthermore, some of the flags are appended after the user-supplied flags, which means
  # that the user no longer has the final word (a rule you should always strive for).
  # Therefore, you should check the build log and/or the meson.build script, and verify
  # that those flags are compatible with the ones you are using on the rest of your embedded system.
  # And you will probably need to check again with each new version of Picolibc.
  # Here are the flags I saw in Picolibc 1.7.6:
  #
  # -Os -g: These flags come from Meson setting 'buildtype', or from settings 'optimization' and 'debug'.
  #
  # -ffunction-sections: This is just a size optimisation. This makefile enables this optimisation and others too.
  #
  # -nostdlib: This flag is not needed, because the GCC phase 1 compiler we are using has no built-in libc.
  #
  # -fno-common: This is the default anyway and seems reasonable.
  #
  # -frounding-math and -fsignaling-nans: These affect the way floating-point calculations behave.
  #
  # -fno-stack-protector: Picolibc does not support yet disabling the stack protector
  #                       only for those files where it would cause problems.
  #
  # Some -Wxxx and -Wno-xxx flags that control compilation warnings. They should not pose any compatibilty problems.

endif


# ------- GDB configuration -------

GDB_SRC_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gdb-$(GDB_VERSION)
GDB_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)/gdb-$(GDB_VERSION)-obj
GDB_TAR_FILE := gdb-$(GDB_VERSION).tar.xz

GDB_UNTAR_SENTINEL := $(GDB_SRC_DIR)/$(call sentinel_filename,GdbDecompress)
GDB_HELP_SENTINEL  := $(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(call sentinel_filename,GdbHelp)
GDB_MAKEFILE         := $(GDB_OBJ_DIR)/Makefile
GDB_MAKE_SENTINEL    := $(GDB_OBJ_DIR)/$(call sentinel_filename,GdbMake)
GDB_INSTALL_SENTINEL := $(GDB_OBJ_DIR)/$(call sentinel_filename,GdbInstall)


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

# If you are using GDB versions prior to 10.1:
#   We cannot use INSTALL_TARGET here, because unfortunately GDB does not support the 'install-strip' target,
#   at least as of versions 8.1 and 9.1. The error message is about not finding makefile recipes for targets
#   'install-strip', or 'install-strip-readline' and 'install-strip-sim'.
#   I reported this issue, and the fix is targetted at GDB version 10.1:
#     https://sourceware.org/bugzilla/show_bug.cgi?id=24572
#   As a workaround, use target 'install'.
GDB_INSTALL_TARGET := install-strip


# ----------------- Create the directory where the toolchain build files (object files, etc) will land -----------------

# This rule used to just creates a directory. Instead of a sentinel file for this rule, we could have used an "order-only prerequisite".
# But now other files are created inside that directory.
$(CROSS_TOOLCHAIN_BUILD_DIR_SENTINEL):
	echo && \
	echo "Creating directory \"$(CROSS_TOOLCHAIN_BUILD_DIR)\"..." && \
	mkdir --parents -- "$(CROSS_TOOLCHAIN_BUILD_DIR)" && \
	mkdir -- "$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)" && \
	mkdir -- "$(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)" && \
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

$(BINUTILS_HELP_SENTINEL): $(BINUTILS_UNTAR_SENTINEL)
	$(call store_recursive_help,BINUTILS_SRC_DIR,BinUtils)

$(BINUTILS_MAKEFILE): $(BINUTILS_HELP_SENTINEL)
	echo && \
	echo "Configuring Binutils from $(BINUTILS_SRC_DIR)/ to $(BINUTILS_OBJ_DIR)/" && \
	if [ -d "$(BINUTILS_OBJ_DIR)" ]; then rm -rf -- "$(BINUTILS_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(BINUTILS_OBJ_DIR)" && \
	pushd "$(BINUTILS_OBJ_DIR)" >/dev/null && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="BinutilsConfig" \
	    --userFriendlyName="BinUtils Configuration" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsConfig.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsConfig.report" \
	  $(BINUTILS_SRC_DIR)/configure \
	    $(CONFIG_CACHE_OPTION)  \
	    $(HOST_FLAGS_WITH_OPT_AND_LTO) \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --target=$(TARGET_ARCH) \
	    $(BINUTILS_CONFIGURE_OPTIONS) \
	    --disable-nls && \
	popd >/dev/null && \
	echo "The Binutils configuration has finished."

$(BINUTILS_MAKE_SENTINEL): $(BINUTILS_MAKEFILE)
	echo && \
	echo "Building Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="BinutilsMake" \
	    --userFriendlyName="BinUtils Make" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsMake.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsMake.report" \
	  $(MAKE) -C "$(BINUTILS_OBJ_DIR)" && \
	echo "The Binutils build has finished." >"$(BINUTILS_MAKE_SENTINEL)" && \
	echo "The Binutils build has finished."

# Note that Binutils' 'install' makefile target has a race condition bug at least up to version 2.43.1,
# so that, if you run it in parallel, you get sporadic errors like this:
#   GEN      doc/asconfig.texi
#   chmod: cannot access 'doc/asconfig.texi': No such file or directory
# I reported the bug here:
#   https://sourceware.org/bugzilla/show_bug.cgi?id=32254
# Therefore, it is imperative that we use CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS here.

$(BINUTILS_INSTALL_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo && \
	echo "Installing Binutils ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="BinutilsInstall" \
	    --userFriendlyName="BinUtils Install" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsInstall.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsInstall.report" \
	  $(MAKE) -C "$(BINUTILS_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The Binutils installation has finished." >"$(BINUTILS_INSTALL_SENTINEL)" && \
	echo "The Binutils installation has finished."

$(BINUTILS_INSTALL_SENTINEL_PHASE_1): $(BINUTILS_MAKE_SENTINEL)
	echo && \
	echo "Installing Binutils to separate phase 1 directory..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="BinutilsPhase1Install" \
	    --userFriendlyName="BinUtils Phase 1 Install" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsPhase1Install.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsPhase1Install.report" \
	  $(MAKE) -C "$(BINUTILS_OBJ_DIR)" DESTDIR="$(PHASE_1_DESTDIR)" "$(INSTALL_TARGET)" && \
	echo "The Binutils phase 1 installation has finished." >"$(BINUTILS_INSTALL_SENTINEL_PHASE_1)" && \
	echo "The Binutils phase 1 installation has finished."

$(BINUTILS_CHECK_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo && \
	echo "Checking Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="BinutilsCheck" \
	    --userFriendlyName="BinUtils Check" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsCheck.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/BinUtilsCheck.report" \
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

$(GMP_HELP_SENTINEL): $(GMP_UNTAR_SENTINEL)
	$(call store_recursive_help,GMP_SRC_DIR,Gmp)

$(GMP_MAKEFILE): $(GMP_HELP_SENTINEL)
	echo && \
	echo "Configuring GMP from $(GMP_SRC_DIR)/ to $(GMP_OBJ_DIR)/" && \
	if [ -d "$(GMP_OBJ_DIR)" ]; then rm -rf -- "$(GMP_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GMP_OBJ_DIR)" && \
	pushd "$(GMP_OBJ_DIR)" >/dev/null && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GmpConfigure" \
	    --userFriendlyName="GMP Configure" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpConfigure.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpConfigure.report" \
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
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GmpMake" \
	    --userFriendlyName="GMP Make" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpMake.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpMake.report" \
	  $(MAKE) -C "$(GMP_OBJ_DIR)" && \
	echo "The GMP build has finished." >"$(GMP_MAKE_SENTINEL)" && \
	echo "The GMP build has finished."

$(GMP_INSTALL_SENTINEL): $(GMP_MAKE_SENTINEL)
	echo && \
	echo "Installing GMP ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GmpInstall" \
	    --userFriendlyName="GMP Install" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpInstall.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpInstall.report" \
	  $(MAKE) -C "$(GMP_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The GMP installation has finished." >"$(GMP_INSTALL_SENTINEL)" && \
	echo "The GMP installation has finished."

$(GMP_CHECK_SENTINEL): $(GMP_MAKE_SENTINEL)
	echo && \
	echo "Checking GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GmpCheck" \
	    --userFriendlyName="GMP Check" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpCheck.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GmpCheck.report" \
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

$(MPFR_HELP_SENTINEL): $(MPFR_UNTAR_SENTINEL)
	$(call store_recursive_help,MPFR_SRC_DIR,Mpfr)

$(MPFR_MAKEFILE): $(MPFR_HELP_SENTINEL)  $(GMP_INSTALL_SENTINEL)
	echo && \
	echo "Configuring MPFR from $(MPFR_SRC_DIR)/ to $(MPFR_OBJ_DIR)/" && \
	if [ -d "$(MPFR_OBJ_DIR)" ]; then rm -rf -- "$(MPFR_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(MPFR_OBJ_DIR)" && \
	pushd "$(MPFR_OBJ_DIR)" >/dev/null && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpfrConfigure" \
	    --userFriendlyName="MPFR Configure" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrConfigure.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrConfigure.report" \
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
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpfrMake" \
	    --userFriendlyName="MPFR Make" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrMake.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrMake.report" \
	  $(MAKE) -C "$(MPFR_OBJ_DIR)" && \
	echo "The MPFR build has finished." >"$(MPFR_MAKE_SENTINEL)" && \
	echo "The MPFR build has finished."

$(MPFR_INSTALL_SENTINEL): $(MPFR_MAKE_SENTINEL)
	echo && \
	echo "Installing MPFR ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpfrInstall" \
	    --userFriendlyName="MPFR Install" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrInstall.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrInstall.report" \
	  $(MAKE) -C "$(MPFR_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The MPFR installation has finished." >"$(MPFR_INSTALL_SENTINEL)" && \
	echo "The MPFR installation has finished."

$(MPFR_CHECK_SENTINEL): $(MPFR_MAKE_SENTINEL)
	echo && \
	echo "Checking MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpfrCheck" \
	    --userFriendlyName="MPFR Check" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrCheck.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpfrCheck.report" \
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

$(MPC_HELP_SENTINEL): $(MPC_UNTAR_SENTINEL)
	$(call store_recursive_help,MPC_SRC_DIR,Mpc)

$(MPC_MAKEFILE): $(MPC_HELP_SENTINEL)  $(GMP_INSTALL_SENTINEL)  $(MPFR_INSTALL_SENTINEL)
	echo && \
	echo "Configuring MPC from $(MPC_SRC_DIR)/ to $(MPC_OBJ_DIR)/" && \
	if [ -d "$(MPC_OBJ_DIR)" ]; then rm -rf -- "$(MPC_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(MPC_OBJ_DIR)" && \
	pushd "$(MPC_OBJ_DIR)" >/dev/null && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpcConfigure" \
	    --userFriendlyName="MPC Configure" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcConfigure.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcConfigure.report" \
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
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpcMake" \
	    --userFriendlyName="MPC Make" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcMake.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcMake.report" \
	  $(MAKE) -C "$(MPC_OBJ_DIR)" && \
	echo "The MPC build has finished." >"$(MPC_MAKE_SENTINEL)" && \
	echo "The MPC build has finished."

$(MPC_INSTALL_SENTINEL): $(MPC_MAKE_SENTINEL)
	echo && \
	echo "Installing MPC ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpcInstall" \
	    --userFriendlyName="MPC Install" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcInstall.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcInstall.report" \
	  $(MAKE) -C "$(MPC_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The MPC installation has finished." >"$(MPC_INSTALL_SENTINEL)" && \
	echo "The MPC installation has finished."

$(MPC_CHECK_SENTINEL): $(MPC_MAKE_SENTINEL)
	echo && \
	echo "Checking MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="MpcCheck" \
	    --userFriendlyName="MPC Check" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcCheck.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/MpcCheck.report" \
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
	if [ -n "$(GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME)" ]; then \
	  echo "Applying patch \"$(GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME)\" ..." && \
	  patch -p0 --fuzz=0 --forward <"$(MAKEFILE_PATCHES_DIR)/$(GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME)"; \
	fi && \
	if [ -n "$(IS_GCC_12_X)" ]; then \
	  echo "Applying $(GCC_12_EH_GLOBALS_ATEXIT_PATCH_FILENAME) ..." && \
	  patch -p0 --fuzz=0 --forward <"$(MAKEFILE_PATCHES_DIR)/$(GCC_12_EH_GLOBALS_ATEXIT_PATCH_FILENAME)"; \
	fi && \
	popd >/dev/null && \
	echo "Unpacking GCC finished." >"$(GCC_UNTAR_SENTINEL)" && \
	echo "Unpacking GCC finished."

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  $(GCC1_MAKEFILE): $(MPC_INSTALL_SENTINEL)
endif

ifeq ($(INSTALL_GCC_PHASE_1_TO_SEPARATE_DIR),1)
  $(GCC1_MAKEFILE): $(BINUTILS_INSTALL_SENTINEL_PHASE_1)
  # Serialise the execution of Binutils' makefile, in order to prevent concurrency problems.
  $(BINUTILS_INSTALL_SENTINEL): $(BINUTILS_INSTALL_SENTINEL_PHASE_1)
else
  $(GCC1_MAKEFILE): $(BINUTILS_INSTALL_SENTINEL)
endif

$(GCC_HELP_SENTINEL): $(GCC_UNTAR_SENTINEL)
	$(call store_recursive_help,GCC_SRC_DIR,Gcc)

$(GCC1_MAKEFILE): $(GCC_HELP_SENTINEL)
	echo && \
	echo "Configuring GCC phase 1 from $(GCC_SRC_DIR)/ to $(GCC1_OBJ_DIR)/" && \
	if [ -d "$(GCC1_OBJ_DIR)" ]; then rm -rf -- "$(GCC1_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GCC1_OBJ_DIR)" && \
	pushd "$(GCC1_OBJ_DIR)" >/dev/null && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GccPhase1Configure" \
	    --userFriendlyName="GCC Phase 1 Configure" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Configure.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Configure.report" \
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
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GccPhase1Make" \
	    --userFriendlyName="GCC Phase 1 Make" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Make.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Make.report" \
	  $(MAKE) -C "$(GCC1_OBJ_DIR)" all-gcc && \
	echo "The GCC phase 1 build has finished." >"$(GCC1_MAKE_SENTINEL)" && \
	echo "The GCC phase 1 build has finished."

# We can use here targets 'install-gcc' or 'install-strip-gcc'.

$(GCC1_INSTALL_SENTINEL): $(GCC1_MAKE_SENTINEL)
	echo && \
	echo "Installing GCC phase 1 ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GccPhase1Install" \
	    --userFriendlyName="GCC Phase 1 Install" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Install.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase1Install.report" \
	  $(MAKE) -C "$(GCC1_OBJ_DIR)" $(INSTALL_TARGET)-gcc && \
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

# Note that we are getting the help only for subdir newlib/ , and not for example libgloss/ .
$(NEWLIB_HELP_SENTINEL): $(NEWLIB_UNTAR_SENTINEL)
	$(call store_recursive_help_ignore_error,NEWLIB_HELP_DIR,Newlib)

$(NEWLIB_MAKEFILE): $(NEWLIB_HELP_SENTINEL) $(GCC1_INSTALL_SENTINEL)
	echo && \
	echo "About to configure Newlib from $(NEWLIB_SRC_DIR)/ to $(NEWLIB_OBJ_DIR)/" && \
	if [ -d "$(NEWLIB_OBJ_DIR)" ]; then rm -rf -- "$(NEWLIB_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(NEWLIB_OBJ_DIR)" && \
	pushd "$(NEWLIB_OBJ_DIR)" >/dev/null && \
	echo "Configuring Newlib:" && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="NewlibConfigure" \
	      --userFriendlyName="Newlib Configure" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibConfigure.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibConfigure.report" \
	    CFLAGS_FOR_TARGET="$(NEWLIB_C_AND_CXX_FLAGS_FOR_TARGET)" \
	    CXXFLAGS_FOR_TARGET="$(NEWLIB_C_AND_CXX_FLAGS_FOR_TARGET)" \
	    $(NEWLIB_SRC_DIR)/configure \
	      $(NEWLIB_CFG_FLAGS) && \
	popd >/dev/null && \
	echo "The Newlib configuration has finished."

$(NEWLIB_MAKE_SENTINEL): $(NEWLIB_MAKEFILE)
	echo && \
	echo "Building Newlib ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="NewlibMake" \
	      --userFriendlyName="Newlib Make" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibMake.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibMake.report" \
	    $(MAKE) -C "$(NEWLIB_OBJ_DIR)"  && \
	echo "The Newlib build has finished." >"$(NEWLIB_MAKE_SENTINEL)" && \
	echo "The Newlib build has finished."

$(NEWLIB_INSTALL_SENTINEL): $(NEWLIB_MAKE_SENTINEL)
	echo && \
	echo "Installing Newlib ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="NewlibInstall" \
	      --userFriendlyName="Newlib Install" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibInstall.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/NewlibInstall.report" \
	    $(MAKE) -C "$(NEWLIB_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The Newlib installation has finished." >"$(NEWLIB_INSTALL_SENTINEL)" && \
	echo "The Newlib installation has finished."

# This target provides a friendly name useful when testing this makefile.
libc-install: $(NEWLIB_INSTALL_SENTINEL)

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
	echo "Generating $(PICOLIBC_TARGET_FLAGS_FILENAME) ..." && \
	"$(MAKEFILE_TOOLS_DIR)/GeneratePicolibcCrossFile.sh" \
	  --target-arch="$(TARGET_ARCH)"          \
	  --cpu-family="$(PICOLIBC_CPU_FAMILY)"   \
	  --cpu="$(TOOLCHAIN_TARGET_CPU)"         \
	  --endianness=$(PICOLIBC_CPU_ENDIANNESS) \
	  $(patsubst %,--cflag=%,$(PICOLIBC_C_FLAGS_FOR_TARGET)) \
	  >"$(PICOLIBC_OBJ_DIR)/$(PICOLIBC_TARGET_FLAGS_FILENAME)" && \
	pushd "$(PICOLIBC_OBJ_DIR)" >/dev/null && \
	echo "Configuring Picolibc:" && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="PicolibcConfigure" \
	      --userFriendlyName="Picolibc Configure" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcConfigure.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcConfigure.report" \
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
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="PicolibcMake" \
	      --userFriendlyName="Picolibc Make" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcMake.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcMake.report" \
	    meson compile --verbose  -C "$(PICOLIBC_OBJ_DIR)"  && \
	echo "The Picolibc build has finished." >"$(PICOLIBC_MAKE_SENTINEL)" && \
	echo "The Picolibc build has finished."

# CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS below is actually intended for GNU Make,
# not for Meson, but other such build tools could also use GNU Make's job server.

$(PICOLIBC_INSTALL_SENTINEL): $(PICOLIBC_MAKE_SENTINEL)
	echo && \
	echo "Installing Picolibc ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	PATH=$(PHASE_1_PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="PicolibcInstall" \
	      --userFriendlyName="Picolibc Install" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcInstall.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/PicolibcInstall.report" \
	    meson install  -C "$(PICOLIBC_OBJ_DIR)"  && \
	echo "The Picolibc installation has finished." >"$(PICOLIBC_INSTALL_SENTINEL)" && \
	echo "The Picolibc installation has finished."

# This target provides a friendly name useful when testing this makefile.
libc-install: $(PICOLIBC_INSTALL_SENTINEL)

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
  $(GCC2_MAKEFILE): $(NEWLIB_INSTALL_SENTINEL)
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
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="GccPhase2Configure" \
	      --userFriendlyName="GCC Phase 2 Configure" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Configure.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Configure.report" \
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
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="GccPhase2Make" \
	      --userFriendlyName="GCC Phase 2 Make" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Make.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Make.report" \
	    $(MAKE) -C "$(GCC2_OBJ_DIR)" \
	      CFLAGS_FOR_TARGET="$(GCC_C_AND_CXX_FLAGS_FOR_TARGET)" \
	      CXXFLAGS_FOR_TARGET="$(GCC_C_AND_CXX_FLAGS_FOR_TARGET)" && \
	echo "The GCC phase 2 build has finished." >"$(GCC2_MAKE_SENTINEL)" && \
	echo "The GCC phase 2 build has finished."

# The "make install" step needs the PATH set because it uses Binutils tools like 'arm-none-eabi-ranlib',
# and it does not seem able to find them via the configured '--prefix' directory.

$(GCC2_INSTALL_SENTINEL): $(GCC2_MAKE_SENTINEL)
	echo && \
	echo "Installing GCC phase 2 ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	PATH=$(PATH_DIR):$$PATH \
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="GccPhase2Install" \
	      --userFriendlyName="GCC Phase 2 Install" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Install.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Install.report" \
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
	  "$(RUN_AND_REPORT_TOOL_PATH)" \
	      --id="GccPhase2Check" \
	      --userFriendlyName="GCC Phase 2 Check" \
	      --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Check.log" \
	      --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GccPhase2Check.report" \
	    $(MAKE) -C "$(GCC2_OBJ_DIR)" check \
	      CFLAGS_FOR_TARGET="$(GCC_C_AND_CXX_FLAGS_FOR_TARGET)" \
	      CXXFLAGS_FOR_TARGET="$(GCC_C_AND_CXX_FLAGS_FOR_TARGET)" && \
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

$(GDB_HELP_SENTINEL): $(GDB_UNTAR_SENTINEL)
	$(call store_recursive_help,GDB_SRC_DIR,Gdb)

$(GDB_MAKEFILE): $(GDB_HELP_SENTINEL)
	echo && \
	echo "Configuring GDB from $(GDB_SRC_DIR)/ to $(GDB_OBJ_DIR)/" && \
	if [ -d "$(GDB_OBJ_DIR)" ]; then rm -rf -- "$(GDB_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GDB_OBJ_DIR)" && \
	pushd "$(GDB_OBJ_DIR)" >/dev/null && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GdbConfigure" \
	    --userFriendlyName="GDB Configure" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbConfigure.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbConfigure.report" \
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
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GdbMake" \
	    --userFriendlyName="GDB Make" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbMake.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbMake.report" \
	  $(MAKE) -C "$(GDB_OBJ_DIR)" && \
	echo "The GDB build has finished." >"$(GDB_MAKE_SENTINEL)" && \
	echo "The GDB build has finished."

$(GDB_INSTALL_SENTINEL): $(GDB_MAKE_SENTINEL)
	echo && \
	echo "Installing GDB ..." && \
	$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && \
	"$(RUN_AND_REPORT_TOOL_PATH)" \
	    --id="GdbInstall" \
	    --userFriendlyName="GDB Install" \
	    --logFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbInstall.log" \
	    --reportFilename="$(CROSS_TOOLCHAIN_BUILD_DIR_LOG_FILES)/GdbInstall.report" \
	  $(MAKE) -C "$(GDB_OBJ_DIR)" "$(GDB_INSTALL_TARGET)" && \
	echo "The GDB installation has finished." >"$(GDB_INSTALL_SENTINEL)" && \
	echo "The GDB installation has finished."

# Short target name for building and installing GDB. Sometimes useful when testing this makefile.
gdb: $(GDB_INSTALL_SENTINEL)


# --------------- Top-level rules ---------------

.PHONY: $(TARGET_NAME_ALL) $(TARGET_NAME_HELP) $(TARGET_NAME_CLEAN)
.PHONY: $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET) $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER)
.PHONY: $(TARGET_NAME_TEST_MAKEFLAGS_NORMAL)
.PHONY: $(TARGET_NAME_TEST_MAKEFLAGS_INSTALL)
.PHONY: $(TARGET_NAME_CHECK)

.DEFAULT_GOAL := help

$(TARGET_NAME_HELP):
	@echo
	@echo "This makefile builds a GCC/Newlib toolchain for a 'bare metal' programming environment"
	@echo "for an ARM Cortex-M3 microcontroller. Other CPUs are supported, search for"
	@echo "TOOLCHAIN_TARGET_CPU in the makefile for details. You can also use Picolibc"
	@echo "instead of Newlib by specifying TARGET_LIBC=picolibc ."
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
	@echo "   builds GMP, MPFR and MPC itself by default, but you can switch it off with BUILD_GMP_MPFR_MPC=0."
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
	@echo "        --no-builtin-variables --warn-undefined-variables \\"
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


TARGET_ALL_SENTINEL := $(CROSS_TOOLCHAIN_BUILD_DIR)/$(call sentinel_filename,TargetAll)

$(TARGET_ALL_SENTINEL): $(GDB_INSTALL_SENTINEL)  $(GCC2_INSTALL_SENTINEL)
	@echo && \
	echo "Toolchain installed in \"$(CROSS_TOOLCHAIN_DIR)\"." && \
	echo "Toolchain installed in \"$(CROSS_TOOLCHAIN_DIR)\"." >"$(TARGET_ALL_SENTINEL)" && \
	if [ $(SHOULD_WARN_ABOUT_REBUILDING_SOFTWARE) -ne 0 ]; then \
	echo "WARNING: After a toolchain change you should rebuild all software built with it from scratch." ; \
	fi

.PHONY: AllHelpFiles

AllHelpFiles: $(BINUTILS_HELP_SENTINEL)
AllHelpFiles: $(GCC_HELP_SENTINEL)
AllHelpFiles: $(GDB_HELP_SENTINEL)
ifeq ($(TARGET_LIBC), newlib)
  AllHelpFiles: $(NEWLIB_HELP_SENTINEL)
endif
ifeq ($(BUILD_GMP_MPFR_MPC),1)
  AllHelpFiles: $(GMP_HELP_SENTINEL)
  AllHelpFiles: $(MPFR_HELP_SENTINEL)
  AllHelpFiles: $(MPC_HELP_SENTINEL)
endif


$(TARGET_NAME_ALL): $(TARGET_ALL_SENTINEL) AllHelpFiles


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


$(TARGET_NAME_TEST_MAKEFLAGS_NORMAL):
	@$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && echo "MAKEFLAGS passed in the environment for normal targets: $$MAKEFLAGS"

$(TARGET_NAME_TEST_MAKEFLAGS_INSTALL):
	@$(CLEAR_MAKEFLAGS_FOR_INSTALL_TARGETS) && echo "MAKEFLAGS passed in the environment for 'install' targets: $$MAKEFLAGS"


$(TARGET_NAME_CHECK): $(BINUTILS_CHECK_SENTINEL)

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  $(TARGET_NAME_CHECK): $(GMP_CHECK_SENTINEL) $(MPFR_CHECK_SENTINEL) $(MPC_CHECK_SENTINEL)
endif

# We cannot run the GCC checks on the host PC:
# $(TARGET_NAME_CHECK): $(GCC2_CHECK_SENTINEL)

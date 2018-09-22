
# Run "make help" for information about how to use this makefile.
#
# Copyright (c) 2013-2018 - R. Diez - Licensed under the GNU AGPLv3.


.DELETE_ON_ERROR:

# This makefile has only been tested with bash.
# Option 'pipefail' is necessary. Otherwise, piping to 'tee' would mask any errors on
# the left side of the pipeline.
SHELL := bash -o nounset -o pipefail
# This way of passing shell options is only available in modern GNU Make versions,
# and not in version 3.81 shipped with Ubuntu 14.04:
#   .SHELLFLAGS := -o nounset -o pipefail -e -c


# ------- Common variables -------

THIS_MAKEFILE_DIR := $(shell readlink --verbose --canonicalize -- "$(CURDIR)")

CROSS_TOOLCHAIN_BUILD_DIR := $(THIS_MAKEFILE_DIR)/Tmp

# The name above is documented in the help text. Alternatively, we could rename all occurences
# of TOOLCHAIN_OBJ_DIR in this makefile to CROSS_TOOLCHAIN_BUILD_DIR:
TOOLCHAIN_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)


verify_variable_is_defined = $(if $(filter undefined,$(origin $(1))),$(error "The variable '$(1)' is not defined, but it should be at this point."))


# Targets 'help', 'clean' and download-tarballs-from-* do not build, all other targets (usually 'all') do build.
TARGET_NAME_ALL := all
TARGET_NAME_HELP := help
TARGET_NAME_CLEAN := clean
TARGET_NAME_CHECK := check
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET := download-tarballs-from-internet
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER := download-tarballs-from-file-server
TARGET_NAME_TEST_MAKEFLAGS := test-makeflags

ifeq ($(strip $(MAKECMDGOALS)),)
  # The default target is 'help'
  IS_BUILDING := 0
else ifneq ($(filter $(TARGET_NAME_HELP), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
else ifneq ($(filter $(TARGET_NAME_CLEAN), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
else ifneq ($(filter $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
else ifneq ($(filter $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
  $(call verify_variable_is_defined,PATH_TO_TARBALLS_ON_FILE_SERVER)
else ifneq ($(filter $(TARGET_NAME_TEST_MAKEFLAGS), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
else
  IS_BUILDING := 1
endif


# ------- User Configuration -------

VERSION_SET := VersionSet1

ifeq ($(VERSION_SET),VersionSet1)

  # This is the version set I have tested most.

  BINUTILS_VERSION := 2.30
  GMP_VERSION := 6.1.2
  MPFR_VERSION := 3.1.6
  MPC_VERSION := 1.0.3
  GCC_VERSION := 7.3.0
  NEWLIB_VERSION := 3.0.0.20180226
  GDB_VERSION := 8.1

else ifeq ($(VERSION_SET),VersionSet2)

  # I have not tested this version set thoroughly yet.
  # I immediately hit the following GDB 8.1 bug, so I am waiting for GDB 8.2:
  #   https://sourceware.org/bugzilla/show_bug.cgi?id=23010

  BINUTILS_VERSION := 2.31.1
  GMP_VERSION := 6.1.2
  MPFR_VERSION := 3.1.6
  MPC_VERSION := 1.1.0
  GCC_VERSION := 8.2.0
  NEWLIB_VERSION := 3.0.0.20180802
  GDB_VERSION := 8.1.1

else
  $(error Invalid configuration set "$(VERSION_SET)")
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
HF :=

# Building without debug information cuts the Binutils build time alone with GCC 5.4.0 and
# "-O3 -march=native" on my Intel Core i3 M 380 from 5 minutes, 22 seconds to 4 minutes.
# You need to explicitly add -g0 to disable debug information, because some components
# automatically prepend the compiler flags with '-g'.
HF += -g0

# The GCC compiler and the Binutils linker, among other components, need to do heavy lifting,
# so we want to optimise them as much as we reasonably can.
# In the future, when building the toolchain with GCC version 7 and onwards,
# we should try and build with LTO.
HF += -O3

# Building for the current CPU makes this toolchain not portable, but can yield
# a good performance boost, especially on newer CPUs.
HF += -march=native

HOST_FLAGS := CFLAGS="$(HF)"  CXXFLAGS="$(HF)"


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
CONFIGURE_CACHE_FILENAME := $(TOOLCHAIN_OBJ_DIR)/build-toolchain-local-cache-file.cache

# I have decided not to share a common cache file. Reasons are:
# 1) The 'configure' scripts from different projects are potentially called in parallel,
#    and I am not sure that updating cache files in parallel is safe.
# 2) Most projects create further "config.cache" files in their subprojects, so the caches
#    do not seem to get reused much.
#   CONFIG_CACHE_OPTION := --cache-file="$(CONFIGURE_CACHE_FILENAME)"
CONFIG_CACHE_OPTION := --config-cache

REMOVE_STRERROR_MESSAGES := 1

DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER := 1

# Recent GCC versions may require newer versions of the GMP, MPFR and MPC
# libraries than the ones available in your linux distribution.
# With this option you can choose whether to download a build these libraries too.
BUILD_GMP_MPFR_MPC := 1

SHOULD_WARN_ABOUT_REBUILDING_SOFTWARE := 1


# ------- Miscellaneous definitions -------

ARM_TARGET := arm-none-eabi

SENTINEL_FILENAME_PREFIX := ToolchainBuilder-

TARBALLS_DOWNLOAD_DIR := $(THIS_MAKEFILE_DIR)/Tarballs

# Check if variable CROSS_TOOLCHAIN_DIR is set, but only if the user asked for a build.
ifeq ($(IS_BUILDING),1)
  $(call verify_variable_is_defined,CROSS_TOOLCHAIN_DIR)
  PATH_DIR := $(CROSS_TOOLCHAIN_DIR)/bin
else
  # Prevent some warnings when not building and using '--warn-undefined-variables'.
  CROSS_TOOLCHAIN_DIR := this-value-should-not-be-used
endif


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

EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS = $(strip $(filter -j%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-fds=%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-auth=%,$(MAKEFLAGS)) \
                                                $(filter -O%,$(MAKEFLAGS)))
EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS = export MAKEFLAGS="$(EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS)"


# ------- Build directory definitions -------

TOOLCHAIN_OBJ_DIR_SENTINEL := $(TOOLCHAIN_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MkdirSentinel


# ------- Common C/C++ Compilation flags -------

# WARNING: The following components must be ABI compatible, which means they must be compiled
#          with similar CFLAGS:
# - Newlib
#   Keep in mind that Newlib's configure.host  may provide additional compilation flags.
#   The best thing to do is probably to run this makefile once and then look for the compilation flags
#   in the log output of some Newlib source file like "strlen.c".
# - GCC's libgcc und libstdc++
# - Your operating system and application, so you will have to keep the CFLAGS/CXXFLAGS in your
#   own makefile in sync with this one.

COMMON_CFLAGS :=


# --- Debug oder Release Toolchain.

ifeq ($(ENABLE_DEBUG_TOOLCHAIN), 0)
  COMMON_CFLAGS += -g -Os
  ifeq ($(IS_BUILDING),1)
    $(info Building a release (non-debug) toolchain.)
  endif
else ifeq ($(ENABLE_DEBUG_TOOLCHAIN), 1)
  COMMON_CFLAGS += -g -Og -DDEBUG
  ifeq ($(IS_BUILDING),1)
    $(info Building a debug toolchain.)
  endif
else
  $(error Variable ENABLE_DEBUG_TOOLCHAIN has invalid value "$(ENABLE_DEBUG_TOOLCHAIN)")
endif


# --- Target CPU.

FLAGS_NO_HARDWARE_FP := --without-fp --with-float=soft

ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m0)
  COMMON_CFLAGS += -mcpu=cortex-m0 -mthumb
  GCC_FLOATING_POINT_FLAGS := $(FLAGS_NO_HARDWARE_FP)
else ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m3)
  COMMON_CFLAGS += -mcpu=cortex-m3 -mthumb
  GCC_FLOATING_POINT_FLAGS := $(FLAGS_NO_HARDWARE_FP)
else ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m4f)
  COMMON_CFLAGS += -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
  GCC_FLOATING_POINT_FLAGS := # No flags needed here.
else
  $(error Variable TOOLCHAIN_TARGET_CPU has invalid value "$(TOOLCHAIN_TARGET_CPU)")
endif

ifeq ($(IS_BUILDING),1)
  $(info Building toolchain for CPU "$(TOOLCHAIN_TARGET_CPU)".)
endif


# --- Other flags.

# Frame pointers are generally useful in order to investigate crash dumps or to debug an optimised build.
# They do cost a little in terms of stack space, code space and performance, though.
COMMON_CFLAGS += -fno-omit-frame-pointer
COMMON_CFLAGS += -fdata-sections      # Keeps data in separate data sections, so they can be discarded if unused.
COMMON_CFLAGS += -ffunction-sections  # Keeps functions in separate data sections, so they can be discarded if unused.

# I did one quick test, and enabling exceptions here did not add any code when building the toolchain with -Os
# and the application without exceptions enabled. Therefore, I am leaving exceptions enabled here
# even though the application might never not use them.
#   COMMON_CFLAGS += -fno-exceptions


# ------- Binutils flags -------

BINUTILS_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/binutils-$(BINUTILS_VERSION)
BINUTILS_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/binutils-$(BINUTILS_VERSION)-obj
BINUTILS_TAR_FILE := binutils-$(BINUTILS_VERSION).tar.xz

# Option --enable-plugins is necessary for Gold to understand the --plugin command-line switch that the GCC driver passes.
BINUTILS_GOLD_CONFIGURE_OPTIONS := --enable-gold=yes --enable-plugins

BINUTILS_UNTAR_SENTINEL := $(BINUTILS_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
BINUTILS_MAKEFILE := $(BINUTILS_OBJ_DIR)/Makefile
BINUTILS_MAKE_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
BINUTILS_INSTALL_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)BinutilsInstallSentinel
BINUTILS_CHECK_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)CheckSentinel


# ------- GMP lib flags -------

GMP_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/gmp-$(GMP_VERSION)
GMP_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gmp-$(GMP_VERSION)-obj
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


# ------- MPFR lib flags -------
#
# Version 4.0.x has been released in the meantime, but I could not get
# version 4.0.1 to work with GCC 8.2.0.
# Older versions are still available on the website under "history", or on ftp://ftp.gnu.org/gnu/mpfr/ .

MPFR_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/mpfr-$(MPFR_VERSION)
MPFR_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/mpfr-$(MPFR_VERSION)-obj
MPFR_TAR_FILE := mpfr-$(MPFR_VERSION).tar.xz

MPFR_UNTAR_SENTINEL := $(MPFR_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
MPFR_MAKEFILE := $(MPFR_OBJ_DIR)/Makefile
MPFR_MAKE_SENTINEL := $(MPFR_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
MPFR_INSTALL_SENTINEL := $(MPFR_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpfrInstallSentinel
MPFR_CHECK_SENTINEL := $(MPFR_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpfrCheckSentinel


# ------- MPC lib flags -------
#
# This libray can be downloaded from http://www.multiprecision.org/
# Version 1.1.0 has been released in the meantime, so that it builds against MPFR 4.0.x .

MPC_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/mpc-$(MPC_VERSION)
MPC_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/mpc-$(MPC_VERSION)-obj
MPC_TAR_FILE := mpc-$(MPC_VERSION).tar.gz

MPC_UNTAR_SENTINEL := $(MPC_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
MPC_MAKEFILE := $(MPC_OBJ_DIR)/Makefile
MPC_MAKE_SENTINEL := $(MPC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
MPC_INSTALL_SENTINEL := $(MPC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpcInstallSentinel
MPC_CHECK_SENTINEL := $(MPC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MpcCheckSentinel


# ------- GCC flags -------

# This enables building a debug version of GCC in phase 2, instead of a release version,
# which is only useful if you need to debug GCC itself.

GCC_ENABLE_DEBUG_BUILD := 0

ifeq ($(GCC_ENABLE_DEBUG_BUILD),1)
  GCC_DEBUG_BUILD_FLAGS := CFLAGS="-O0 -g"  CXXFLAGS="-O0 -g"
else
  GCC_DEBUG_BUILD_FLAGS :=
endif

GCC_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/gcc-$(GCC_VERSION)
GCC_TAR_FILE := gcc-$(GCC_VERSION).tar.xz
GCC_UNTAR_SENTINEL := $(GCC_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel

GCC1_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gcc-$(GCC_VERSION)-obj-phase1
GCC1_MAKEFILE := $(GCC1_OBJ_DIR)/Makefile
GCC1_MAKE_SENTINEL := $(GCC1_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)Make1Sentinel
GCC1_INSTALL_SENTINEL := $(GCC1_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)Gcc1InstallSentinel

GCC2_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gcc-$(GCC_VERSION)-obj-phase2
GCC2_MAKEFILE := $(GCC2_OBJ_DIR)/Makefile
GCC2_MAKE_SENTINEL := $(GCC2_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)Make2Sentinel
GCC2_INSTALL_SENTINEL := $(GCC2_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)Gcc2InstallSentinel
GCC2_CHECK_SENTINEL := $(GCC2_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)Gcc2CheckSentinel

GCC_CFLAGS := $(COMMON_CFLAGS)
# GCC_CFLAGS += -H  # Print the name of each header file included, useful during development of this makefile.

COMMON_GCC_OPTIONS :=
COMMON_GCC_OPTIONS += $(HOST_FLAGS)
COMMON_GCC_OPTIONS += $(CONFIG_CACHE_OPTION)
COMMON_GCC_OPTIONS += --prefix="$(CROSS_TOOLCHAIN_DIR)"

COMMON_GCC_OPTIONS += --target=$(ARM_TARGET)
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

COMMON_GCC_OPTIONS += --enable-lto  # This flag is probably only required in GCC phase 2.


ifeq ($(DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER),1)

  IS_GCC_4_9_X := $(filter 4.9.%,$(GCC_VERSION))
  IS_GCC_5_X   := $(filter 5.%,$(GCC_VERSION))
  IS_GCC_6_X   := $(filter 6.%,$(GCC_VERSION))
  IS_GCC_7_X   := $(filter 7.%,$(GCC_VERSION))

  ifneq "$(or $(IS_GCC_4_9_X), $(IS_GCC_5_X), $(IS_GCC_6_X)), $(IS_GCC_7_X))" ""
    # The patch for version 5.3.0 works in the following versions too: 4.9.x, 5.x, 6.x, 7.x.
    GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME := $(THIS_MAKEFILE_DIR)/GccDisableCppExceptionEmergencyBuffer-GCC-5.3.0.patch
  else
    $(error Unknown GCC version)
  endif

else

  GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME := this-patch-filename-should-not-be-used

endif


# ------- Newlib flags -------

NEWLIB_TAR_FILE := newlib-$(NEWLIB_VERSION).tar.gz
NEWLIB_UNTAR_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)
NEWLIB_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)
NEWLIB_NEWLIB_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)-obj

NEWLIB_UNTAR_SENTINEL := $(NEWLIB_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
NEWLIB_NEWLIB_MAKEFILE := $(NEWLIB_NEWLIB_OBJ_DIR)/Makefile
NEWLIB_NEWLIB_MAKE_SENTINEL := $(NEWLIB_NEWLIB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
NEWLIB_NEWLIB_INSTALL_SENTINEL := $(NEWLIB_NEWLIB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)NewlibNewlibInstallSentinel

NEWLIB_USER_IMPLEMENTATION_OF_ASSERT_PATCH_FILENAME := $(THIS_MAKEFILE_DIR)/NewlibUserImplementationOfAssert.patch
NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME := $(THIS_MAKEFILE_DIR)/NewlibRemoveStrerrorMessages.patch

# NOTE: Newlib's switch --enable-target-optspace would add "-g -Os" to the compilation flags, but we have already done that in $(COMMON_CFLAGS)
NEWLIB_CFLAGS := $(COMMON_CFLAGS)

# Newlib's standard assert() implementation ends up calling fiprintf(), which pulls in loads of C runtime I/O functions,
# and we don't want that in our memory-constrained embedded environment.
NEWLIB_CFLAGS += -DHAVE_ASSERT_FUNC


# ------- GDB flags -------

GDB_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/gdb-$(GDB_VERSION)
GDB_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gdb-$(GDB_VERSION)-obj
GDB_TAR_FILE := gdb-$(GDB_VERSION).tar.xz

GDB_UNTAR_SENTINEL := $(GDB_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
GDB_MAKEFILE := $(GDB_OBJ_DIR)/Makefile
GDB_MAKE_SENTINEL := $(GDB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
GDB_INSTALL_SENTINEL := $(GDB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)GdbInstallSentinel


# ----------------- Create the directory where the toolchain build files (object files, etc) will land -----------------

$(TOOLCHAIN_OBJ_DIR_SENTINEL):
	echo "Creating directory \"$(TOOLCHAIN_OBJ_DIR)\"..." && \
	mkdir --parents -- "$(TOOLCHAIN_OBJ_DIR)" && \
	echo "Creation of directory \"$(TOOLCHAIN_OBJ_DIR)\" finished." >"$(TOOLCHAIN_OBJ_DIR_SENTINEL)"

# ----------------- Build Binutils -----------------

$(BINUTILS_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(BINUTILS_TAR_FILE) ..." && \
	if [ -d "$(BINUTILS_SRC_DIR)" ]; then rm -rf "$(BINUTILS_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(BINUTILS_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking Binutils finished." >"$(BINUTILS_UNTAR_SENTINEL)" && \
	echo "Unpacking Binutils finished."

$(BINUTILS_MAKEFILE): $(BINUTILS_UNTAR_SENTINEL)
	echo "Configuring Binutils from $(BINUTILS_SRC_DIR)/ to $(BINUTILS_OBJ_DIR)" && \
	if [ -d "$(BINUTILS_OBJ_DIR)" ]; then rm -rf "$(BINUTILS_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(BINUTILS_OBJ_DIR)" && \
	pushd "$(BINUTILS_OBJ_DIR)" >/dev/null && \
	$(BINUTILS_SRC_DIR)/configure --help && \
	$(BINUTILS_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  $(HOST_FLAGS) \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	  --target=$(ARM_TARGET) \
	  $(BINUTILS_GOLD_CONFIGURE_OPTIONS) \
	  --disable-nls && \
	popd >/dev/null && \
	echo "The Binutils configuration has finished."

$(BINUTILS_MAKE_SENTINEL): $(BINUTILS_MAKEFILE)
	echo "Building Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(BINUTILS_OBJ_DIR)" && \
	echo "The Binutils build has finished." >"$(BINUTILS_MAKE_SENTINEL)" && \
	echo "The Binutils build has finished."

$(BINUTILS_INSTALL_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo "Installing Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(BINUTILS_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The Binutils installation has finished." >"$(BINUTILS_INSTALL_SENTINEL)" && \
	echo "The Binutils installation has finished."

$(BINUTILS_CHECK_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo "Checking Binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(BINUTILS_OBJ_DIR)" check && \
	echo "The Binutils check has finished." >"$(BINUTILS_CHECK_SENTINEL)" && \
	echo "The Binutils check has finished."

# ----------------- Build GMP -----------------

$(GMP_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(GMP_TAR_FILE) ..." && \
	if [ -d "$(GMP_SRC_DIR)" ]; then rm -rf "$(GMP_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(GMP_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking GMP finished." >"$(GMP_UNTAR_SENTINEL)" && \
	echo "Unpacking GMP finished."

$(GMP_MAKEFILE): $(GMP_UNTAR_SENTINEL)
	echo "Configuring GMP from $(GMP_SRC_DIR)/ to $(GMP_OBJ_DIR)" && \
	if [ -d "$(GMP_OBJ_DIR)" ]; then rm -rf "$(GMP_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GMP_OBJ_DIR)" && \
	pushd "$(GMP_OBJ_DIR)" >/dev/null && \
	$(GMP_SRC_DIR)/configure --help && \
	$(GMP_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  $(HOST_FLAGS) \
	  $(FLAGS_TO_BUILD_GMP_ETC_AS_STATIC_ONLY_LIBS) \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The GMP configuration has finished."

$(GMP_MAKE_SENTINEL): $(GMP_MAKEFILE)
	echo "Building GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GMP_OBJ_DIR)" && \
	echo "The GMP build has finished." >"$(GMP_MAKE_SENTINEL)" && \
	echo "The GMP build has finished."

$(GMP_INSTALL_SENTINEL): $(GMP_MAKE_SENTINEL)
	echo "Installing GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GMP_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The GMP installation has finished." >"$(GMP_INSTALL_SENTINEL)" && \
	echo "The GMP installation has finished."

$(GMP_CHECK_SENTINEL): $(GMP_MAKE_SENTINEL)
	echo "Checking GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GMP_OBJ_DIR)" check && \
	echo "The GMP check has finished." >"$(GMP_CHECK_SENTINEL)" && \
	echo "The GMP check has finished."


# ----------------- Build MPFR -----------------

$(MPFR_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(MPFR_TAR_FILE) ..." && \
	if [ -d "$(MPFR_SRC_DIR)" ]; then rm -rf "$(MPFR_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(MPFR_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking MPFR finished." >"$(MPFR_UNTAR_SENTINEL)" && \
	echo "Unpacking MPFR finished."

$(MPFR_MAKEFILE): $(MPFR_UNTAR_SENTINEL)  $(GMP_INSTALL_SENTINEL)
	echo "Configuring MPFR from $(MPFR_SRC_DIR)/ to $(MPFR_OBJ_DIR)" && \
	if [ -d "$(MPFR_OBJ_DIR)" ]; then rm -rf "$(MPFR_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(MPFR_OBJ_DIR)" && \
	pushd "$(MPFR_OBJ_DIR)" >/dev/null && \
	$(MPFR_SRC_DIR)/configure --help && \
	$(MPFR_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  $(HOST_FLAGS) \
	  $(FLAGS_TO_BUILD_GMP_ETC_AS_STATIC_ONLY_LIBS) \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	  --with-gmp="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The MPFR configuration has finished."

$(MPFR_MAKE_SENTINEL): $(MPFR_MAKEFILE)
	echo "Building MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPFR_OBJ_DIR)" && \
	echo "The MPFR build has finished." >"$(MPFR_MAKE_SENTINEL)" && \
	echo "The MPFR build has finished."

$(MPFR_INSTALL_SENTINEL): $(MPFR_MAKE_SENTINEL)
	echo "Installing MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPFR_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The MPFR installation has finished." >"$(MPFR_INSTALL_SENTINEL)" && \
	echo "The MPFR installation has finished."

$(MPFR_CHECK_SENTINEL): $(MPFR_MAKE_SENTINEL)
	echo "Checking MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPFR_OBJ_DIR)" check && \
	echo "The MPFR check has finished." >"$(MPFR_CHECK_SENTINEL)" && \
	echo "The MPFR check has finished."


# ----------------- Build MPC -----------------

$(MPC_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(MPC_TAR_FILE) ..." && \
	if [ -d "$(MPC_SRC_DIR)" ]; then rm -rf "$(MPC_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(MPC_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking MPC finished." >"$(MPC_UNTAR_SENTINEL)" && \
	echo "Unpacking MPC finished."

$(MPC_MAKEFILE): $(MPC_UNTAR_SENTINEL)  $(GMP_INSTALL_SENTINEL)  $(MPFR_INSTALL_SENTINEL)
	echo "Configuring MPC from $(MPC_SRC_DIR)/ to $(MPC_OBJ_DIR)" && \
	if [ -d "$(MPC_OBJ_DIR)" ]; then rm -rf "$(MPC_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(MPC_OBJ_DIR)" && \
	pushd "$(MPC_OBJ_DIR)" >/dev/null && \
	$(MPC_SRC_DIR)/configure --help && \
	$(MPC_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  $(HOST_FLAGS) \
	  $(FLAGS_TO_BUILD_GMP_ETC_AS_STATIC_ONLY_LIBS) \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	  --with-gmp="$(CROSS_TOOLCHAIN_DIR)" \
	  --with-mpfr="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The MPC configuration has finished."

$(MPC_MAKE_SENTINEL): $(MPC_MAKEFILE)
	echo "Building MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPC_OBJ_DIR)" && \
	echo "The MPC build has finished." >"$(MPC_MAKE_SENTINEL)" && \
	echo "The MPC build has finished."

$(MPC_INSTALL_SENTINEL): $(MPC_MAKE_SENTINEL)
	echo "Installing MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPC_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The MPC installation has finished." >"$(MPC_INSTALL_SENTINEL)" && \
	echo "The MPC installation has finished."

$(MPC_CHECK_SENTINEL): $(MPC_MAKE_SENTINEL)
	echo "Checking MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPC_OBJ_DIR)" check && \
	echo "The MPC check has finished." >"$(MPC_CHECK_SENTINEL)" && \
	echo "The MPC check has finished."


# ----------------- GCC phase 1 -----------------

$(GCC_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(GCC_TAR_FILE) ..." && \
	if [ -d "$(GCC_SRC_DIR)" ]; then rm -rf "$(GCC_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(GCC_TAR_FILE)" && \
	popd >/dev/null && \
	pushd "$(GCC_SRC_DIR)" >/dev/null && \
	if [ $(DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER) -ne 0 ]; then \
	  echo "Applying patch \"$(GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME)\" ..." && \
	  patch -p0 --forward <"$(GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME)"; \
	fi && \
	popd >/dev/null && \
	echo "Unpacking GCC finished." >"$(GCC_UNTAR_SENTINEL)" && \
	echo "Unpacking GCC finished."

# Note that GCC's ./configure script will find at least some of
# the Binutils tools under the --prefix directory,
# even if the PATH is not set.

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  $(GCC1_MAKEFILE): $(MPC_INSTALL_SENTINEL)
endif

$(GCC1_MAKEFILE): $(GCC_UNTAR_SENTINEL) $(BINUTILS_INSTALL_SENTINEL)
	echo "Configuring GCC phase 1 from $(GCC_SRC_DIR)/ to $(GCC1_OBJ_DIR)" && \
	if [ -d "$(GCC1_OBJ_DIR)" ]; then rm -rf "$(GCC1_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GCC1_OBJ_DIR)" && \
	pushd "$(GCC1_OBJ_DIR)" >/dev/null && \
	$(GCC_SRC_DIR)/configure --help && \
	PATH=$(PATH_DIR):$$PATH \
      $(GCC_SRC_DIR)/configure \
        --enable-languages=c \
        --without-headers \
        $(COMMON_GCC_OPTIONS) && \
	popd >/dev/null && \
	echo "The GCC phase 1 configuration has finished."

$(GCC1_MAKE_SENTINEL): $(GCC1_MAKEFILE)
	echo "Building GCC phase 1 ..." && \
    $(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC1_OBJ_DIR)" all-gcc && \
    echo "The GCC phase 1 build has finished." >"$(GCC1_MAKE_SENTINEL)" && \
    echo "The GCC phase 1 build has finished."

$(GCC1_INSTALL_SENTINEL): $(GCC1_MAKE_SENTINEL)
	echo "Installing GCC phase 1 ..." && \
    $(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC1_OBJ_DIR)" install-gcc && \
    echo "The GCC phase 1 installation has finished." >"$(GCC1_INSTALL_SENTINEL)" && \
    echo "The GCC phase 1 installation has finished."


# ----------------- Build Newlib -----------------

$(NEWLIB_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(NEWLIB_TAR_FILE) ..." && \
	if [ -d "$(NEWLIB_UNTAR_DIR)" ]; then rm -rf "$(NEWLIB_UNTAR_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(NEWLIB_TAR_FILE)" && \
	popd >/dev/null && \
	pushd "$(NEWLIB_SRC_DIR)" >/dev/null && \
	echo "Applying patch \"$(NEWLIB_USER_IMPLEMENTATION_OF_ASSERT_PATCH_FILENAME)\" ..." && \
	patch -p0 --forward <"$(NEWLIB_USER_IMPLEMENTATION_OF_ASSERT_PATCH_FILENAME)" && \
	if [ $(REMOVE_STRERROR_MESSAGES) -ne 0 ]; then \
	  echo "Applying patch \"$(NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME)\" ..." && \
	  patch -p0 --forward <"$(NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME)"; \
	fi && \
	popd >/dev/null && \
	echo "Unpacking Newlib finished." >"$(NEWLIB_UNTAR_SENTINEL)" && \
	echo "Unpacking Newlib finished."

NEWLIB_CFG_FLAGS :=

NEWLIB_CFG_FLAGS += $(HOST_FLAGS)
NEWLIB_CFG_FLAGS += --prefix="$(CROSS_TOOLCHAIN_DIR)"
NEWLIB_CFG_FLAGS += --target=$(ARM_TARGET)
NEWLIB_CFG_FLAGS += $(CONFIG_CACHE_OPTION)
NEWLIB_CFG_FLAGS += --disable-libssp
NEWLIB_CFG_FLAGS += --enable-newlib-reent-small
NEWLIB_CFG_FLAGS += --disable-newlib-multithread
NEWLIB_CFG_FLAGS += --enable-newlib-io-pos-args
NEWLIB_CFG_FLAGS += --enable-newlib-io-c99-formats
NEWLIB_CFG_FLAGS += --enable-newlib-io-long-long
NEWLIB_CFG_FLAGS += --disable-newlib-io-float
NEWLIB_CFG_FLAGS += --disable-newlib-iconv
NEWLIB_CFG_FLAGS += --disable-newlib-iconv-external-ccs
NEWLIB_CFG_FLAGS += --disable-newlib-mb
NEWLIB_CFG_FLAGS += --disable-newlib-atexit-alloc
NEWLIB_CFG_FLAGS += --disable-shared
NEWLIB_CFG_FLAGS += --disable-multilib
NEWLIB_CFG_FLAGS += --enable-newlib-nano-malloc  # With Newlib's standard malloc library, you get an array in RAM called __malloc_av_ that weighs 1032 bytes, at least on a Cortex-M3 CPU.
NEWLIB_CFG_FLAGS += --enable-newlib-nano-formatted-io  # Warning: you lose support for printing 64-bit integers.

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

$(NEWLIB_NEWLIB_MAKEFILE): $(NEWLIB_UNTAR_SENTINEL) $(GCC1_INSTALL_SENTINEL)
	echo "About to configure Newlib from $(NEWLIB_SRC_DIR)/ to $(NEWLIB_NEWLIB_OBJ_DIR)" && \
	if [ -d "$(NEWLIB_NEWLIB_OBJ_DIR)" ]; then rm -rf "$(NEWLIB_NEWLIB_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(NEWLIB_NEWLIB_OBJ_DIR)" && \
	pushd "$(NEWLIB_NEWLIB_OBJ_DIR)" >/dev/null && \
	echo "Help text from 'configure' script for top-level Newlib dir (see further below for the newlib/ subdir):" && \
	$(NEWLIB_SRC_DIR)/configure --help && \
	echo "Help text from 'configure' script for the newlib/ subdir:" && \
	$(NEWLIB_SRC_DIR)/newlib/configure --help && \
	echo "Configuring Newlib:" && \
	PATH=$(PATH_DIR):$$PATH \
          CFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" CXXFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" \
          $(NEWLIB_SRC_DIR)/configure \
            $(NEWLIB_CFG_FLAGS) && \
	popd >/dev/null && \
	echo "The Newlib configuration has finished."

$(NEWLIB_NEWLIB_MAKE_SENTINEL): $(NEWLIB_NEWLIB_MAKEFILE)
	echo "Building Newlib ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PATH_DIR):$$PATH \
	  $(MAKE) -C "$(NEWLIB_NEWLIB_OBJ_DIR)"  && \
	echo "The Newlib build has finished." >"$(NEWLIB_NEWLIB_MAKE_SENTINEL)" && \
	echo "The Newlib build has finished."

$(NEWLIB_NEWLIB_INSTALL_SENTINEL): $(NEWLIB_NEWLIB_MAKE_SENTINEL)
	echo "Installing Newlib ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	PATH=$(PATH_DIR):$$PATH \
	  $(MAKE) -C "$(NEWLIB_NEWLIB_OBJ_DIR)" "$(INSTALL_TARGET)" && \
	echo "The Newlib installation has finished." >"$(NEWLIB_NEWLIB_INSTALL_SENTINEL)" && \
	echo "The Newlib installation has finished."


# ----------------- GCC phase 2 -----------------

# Note that GCC's ./configure script will find at least some of
# the Binutils tools under the --prefix directory,
# even if the PATH is not set.
$(GCC2_MAKEFILE): $(GCC_UNTAR_SENTINEL) $(NEWLIB_NEWLIB_INSTALL_SENTINEL)
	echo "Configuring GCC phase 2 from $(GCC_SRC_DIR)/ to $(GCC2_OBJ_DIR)" && \
    if [ -d "$(GCC2_OBJ_DIR)" ]; then rm -rf "$(GCC2_OBJ_DIR)"; fi && \
    mkdir --parents -- "$(GCC2_OBJ_DIR)" && \
    pushd "$(GCC2_OBJ_DIR)" >/dev/null && \
    PATH=$(PATH_DIR):$$PATH \
      $(GCC_SRC_DIR)/configure \
        $(GCC_DEBUG_BUILD_FLAGS) \
        --enable-languages=c,c++ \
        $(COMMON_GCC_OPTIONS) && \
    popd >/dev/null && \
    echo "The GCC phase 2 configuration has finished."

$(GCC2_MAKE_SENTINEL): $(GCC2_MAKEFILE)
	echo "Building GCC phase 2 ..." && \
    $(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC2_OBJ_DIR)" \
        CFLAGS_FOR_TARGET="$(GCC_CFLAGS)"  CXXFLAGS_FOR_TARGET="$(GCC_CFLAGS)" && \
    echo "The GCC phase 2 build has finished." >"$(GCC2_MAKE_SENTINEL)" && \
    echo "The GCC phase 2 build has finished."

# NOTE: We should not install GCC phase 2 over phase 1, we should clean it first,
#       but to do that properly would mean making this makefile a lot more complicated,
#       and I have not made the effort yet.

$(GCC2_INSTALL_SENTINEL): $(GCC2_MAKE_SENTINEL)
	echo "Installing GCC phase 2 ..." && \
    $(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC2_OBJ_DIR)" "$(INSTALL_TARGET)" && \
    echo "The GCC phase 2 installation has finished." >"$(GCC2_INSTALL_SENTINEL)" && \
    echo "The GCC phase 2 installation has finished."

$(GCC2_CHECK_SENTINEL): $(GCC2_MAKE_SENTINEL)
	echo "Checking GCC phase 2 ..." && \
    $(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC2_OBJ_DIR)" check \
        CFLAGS_FOR_TARGET="$(GCC_CFLAGS)"  CXXFLAGS_FOR_TARGET="$(GCC_CFLAGS)" && \
    echo "The GCC phase 2 check has finished." >"$(GCC2_CHECK_SENTINEL)" && \
    echo "The GCC phase 2 check has finished."


# ----------------- Build GDB -----------------

# This enables building a debug version of GDB, instead of a release version,
# which is only useful if you need to debug GDB itself.
GDB_ENABLE_DEBUG_BUILD := 0

ifeq ($(GDB_ENABLE_DEBUG_BUILD),1)
  # GDB is written in C only, so CXXFLAGS is not needed yet. But it might be necessary in the future.
  GDB_DEBUG_BUILD_FLAGS := CFLAGS="-O0 -g"  CXXFLAGS="-O0 -g"
else
  GDB_DEBUG_BUILD_FLAGS :=
endif


# We cannot use INSTALL_TARGET here, because unfortunately GDB does not support the 'install-strip' target,
# at least as of version 8.1. The error message is about not finding makefile recipes for targets
# 'install-strip-readline' and 'install-strip-sim'.
GDB_INSTALL_TARGET := install


# GDB does not need Binutils, the GCC cross-compiler, or anything else. It just needs a C compiler on the host.

$(GDB_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(GDB_TAR_FILE) ..." && \
	if [ -d "$(GDB_SRC_DIR)" ]; then rm -rf "$(GDB_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(GDB_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking GDB finished." >"$(GDB_UNTAR_SENTINEL)" && \
	echo "Unpacking GDB finished."

$(GDB_MAKEFILE): $(GDB_UNTAR_SENTINEL)
	echo "Configuring GDB from $(GDB_SRC_DIR)/ to $(GDB_OBJ_DIR)" && \
	if [ -d "$(GDB_OBJ_DIR)" ]; then rm -rf "$(GDB_OBJ_DIR)"; fi && \
	mkdir --parents -- "$(GDB_OBJ_DIR)" && \
	pushd "$(GDB_OBJ_DIR)" >/dev/null && \
	$(GDB_SRC_DIR)/configure --help && \
	PATH=$(PATH_DIR):$$PATH \
	  $(GDB_SRC_DIR)/configure \
	    $(GDB_DEBUG_BUILD_FLAGS) \
	    $(CONFIG_CACHE_OPTION)  \
	    $(HOST_FLAGS) \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --target=$(ARM_TARGET) && \
	popd >/dev/null && \
	echo "The GDB configuration has finished."

$(GDB_MAKE_SENTINEL): $(GDB_MAKEFILE)
	echo "Building GDB ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GDB_OBJ_DIR)" && \
	echo "The GDB build has finished." >"$(GDB_MAKE_SENTINEL)" && \
	echo "The GDB build has finished."

$(GDB_INSTALL_SENTINEL): $(GDB_MAKE_SENTINEL)
	echo "Installing GDB ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GDB_OBJ_DIR)" "$(GDB_INSTALL_TARGET)" && \
	echo "The GDB installation has finished." >"$(GDB_INSTALL_SENTINEL)" && \
	echo "The GDB installation has finished."


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
	@echo "     $(NEWLIB_TAR_FILE)"
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
	@echo "   On Windows/Cygwin, install these packages: gcc-core gcc-g++ automake make curl patch libtool"
	@echo
	@echo "6) Run this makefile for target '$(TARGET_NAME_ALL)'. The recommended command is:"
	@echo
	@echo "   # Remember to delete any old build and installation directories first."
	@echo
	@echo "   make CROSS_TOOLCHAIN_DIR=\"\$$HOME/my-new-toolchain-14-bin\" \\"
	@echo "       CROSS_TOOLCHAIN_BUILD_DIR=\"\$$HOME/my-new-toolchain-14-build\" \\"
	@echo "       --no-builtin-variables --warn-undefined-variables \\"
	@echo "       --output-sync=recurse  -j \"\$$(( \$$(getconf _NPROCESSORS_ONLN) + 1 ))\" \\"
	@echo "       $(TARGET_NAME_ALL)"
	@echo
	@echo "   Option '--output-sync=recurse' above is only available in GNU Make version 4.0 or later."
	@echo
	@echo "7) If you are worried whether the generated toolchain is reliable,"
	@echo "   run target '$(TARGET_NAME_CHECK)' at the end."
	@echo "   You will probably need to install tools like DejaGnu, Tcl, and Expect beforehand."
	@echo "   Full testing is not implemented yet. In order to do it properly, you would need a"
	@echo "   virtual machine for an ARM CPU etc. At the moment, only some components are tested"
	@echo "   with this target."
	@echo

$(TARGET_NAME_ALL): $(GDB_INSTALL_SENTINEL)  $(GCC2_INSTALL_SENTINEL)
	@echo "Toolchain installed in \"$(CROSS_TOOLCHAIN_DIR)\"."
	@if [ $(SHOULD_WARN_ABOUT_REBUILDING_SOFTWARE) -ne 0 ]; then \
	echo "WARNING: After a toolchain change you should rebuild all software built with it from scratch." ; \
	fi

# This 'clean' rule does not delete the toolchain bin directory (variable CROSS_TOOLCHAIN_DIR),
# the user has to delete it manually. I'm not sure whether that is a good idea or not,
# but a toolchain takes long to build and the user may want to save it in case the new one
# does not work correctly.
$(TARGET_NAME_CLEAN):
	@echo "Deleting directory \"$(TOOLCHAIN_OBJ_DIR)\"..."
	@if [ -d "$(TOOLCHAIN_OBJ_DIR)" ]; then rm -rf "$(TOOLCHAIN_OBJ_DIR)"; fi
	@echo "Finished. You may want to delete the toolchain directory you specified originally with variable CROSS_TOOLCHAIN_DIR."


GNU_MIRROR_BASE_URL := http://ftpmirror.gnu.org

DOWNLOAD_TARBALL_TOOL_PATH := ./DownloadTarball.sh

$(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET):
	mkdir --parents -- "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/binutils/$(BINUTILS_TAR_FILE)"           "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/gcc/gcc-$(GCC_VERSION)/$(GCC_TAR_FILE)"  "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/gdb/$(GDB_TAR_FILE)"                     "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "ftp://sourceware.org/pub/newlib/$(NEWLIB_TAR_FILE)"             "$(TARBALLS_DOWNLOAD_DIR)"
	if [ $(BUILD_GMP_MPFR_MPC) -ne 0 ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/gmp/$(GMP_TAR_FILE)"    "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/mpfr/$(MPFR_TAR_FILE)"  "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "$(GNU_MIRROR_BASE_URL)/mpc/$(MPC_TAR_FILE)"    "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	@echo "Finished downloading tarballs from the Internet."

$(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER):
	mkdir --parents -- "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(BINUTILS_TAR_FILE)" "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(GCC_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(GDB_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)"
	"$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(NEWLIB_TAR_FILE)"   "$(TARBALLS_DOWNLOAD_DIR)"
	if [ $(BUILD_GMP_MPFR_MPC) -ne 0 ]; then \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(GMP_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(MPFR_TAR_FILE)"     "$(TARBALLS_DOWNLOAD_DIR)" && \
	  "$(DOWNLOAD_TARBALL_TOOL_PATH)" "file://$(PATH_TO_TARBALLS_ON_FILE_SERVER)/$(MPC_TAR_FILE)"      "$(TARBALLS_DOWNLOAD_DIR)" ; \
	fi
	@echo "Finished downloading tarballs from the file server."

$(TARGET_NAME_TEST_MAKEFLAGS):
	@$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && echo "MAKEFLAGS passed in the environment: $$MAKEFLAGS"

$(TARGET_NAME_CHECK): $(BINUTILS_CHECK_SENTINEL)
$(TARGET_NAME_CHECK): $(GMP_CHECK_SENTINEL) $(MPFR_CHECK_SENTINEL) $(MPC_CHECK_SENTINEL)
# We cannot run the GCC checks on the host PC:
# $(TARGET_NAME_CHECK): $(GCC2_CHECK_SENTINEL)

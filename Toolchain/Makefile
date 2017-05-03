
# Run "make help" for information about how to use this makefile.

.DELETE_ON_ERROR:

# This makefile has only been tested with bash.
# Option 'pipefail' is necessary. Otherwise, piping to 'tee' would mask any errors on
# the left side of the pipeline.
SHELL := bash -o nounset -o pipefail
# This way of passing shell options is only available in modern GNU Make versions,
# and not in version 3.81 shipped with Ubuntu 14.04:
#   .SHELLFLAGS := -o nounset -o pipefail -e -c


# ------- Common variables -------

THIS_MAKEFILE_DIR := $(shell readlink -f "$(CURDIR)")

CROSS_TOOLCHAIN_BUILD_DIR := $(THIS_MAKEFILE_DIR)/Tmp

# The name above is documented in the help text. Alternatively, we could rename all occurences
# of TOOLCHAIN_OBJ_DIR in this makefile to CROSS_TOOLCHAIN_BUILD_DIR:
TOOLCHAIN_OBJ_DIR := $(CROSS_TOOLCHAIN_BUILD_DIR)


verify_variable_is_defined = $(if $(filter undefined,$(origin $(1))),$(error "The variable '$(1)' is not defined, but it should be at this point."))
verify_dir_does_not_exist = $(if $(shell if [ -d "$(1)" ]; then echo exists; fi),$(error Directory "$(1)" already exists, but it should not at this point.))


# Targets 'help', 'clean' and download-tarballs-from-* do not build, all other targets (usually 'all') do build.
TARGET_NAME_ALL := all
TARGET_NAME_HELP := help
TARGET_NAME_CLEAN := clean
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET := download-tarballs-from-internet
TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER := download-tarballs-from-file-server
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
else
  IS_BUILDING := 1
endif


# ------- User Configuration -------

# Setting ENABLE_DEBUG_TOOLCHAIN to '1' builds the toolchain with -DDEBUG in CFLAGS_FOR_TARGET and CXXFLAGS_FOR_TARGET,
# which enables debug code at least in newlib's malloc implementation, and probably in other places too.
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

# Reduce the code size by removing the assert expressions and function names from the failed assertion messages.
# If you need to further reduce the size of your debug build binaries, you could also remove
# the filenames and line positions, but then it would be hard to know which assert just triggered.
# You could try storing only the code address, and then using addr2line in order to lookup the source code position.
USE_SMALLER_ASSERT := 1

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
# We also want to pass flag '--output-sync=target' (aka '-Otarget'), if present.

EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS = $(strip $(filter -j%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-fds=%,$(MAKEFLAGS)) \
                                                $(filter --jobserver-auth=%,$(MAKEFLAGS)) \
                                                $(filter -Otarget,$(MAKEFLAGS)))
EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS = export MAKEFLAGS="$(EXTRACT_SELECTED_FLAGS_FROM_MAKEFLAGS)"


# ------- Build directory definitions -------

TOOLCHAIN_OBJ_DIR_SENTINEL := $(TOOLCHAIN_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MkdirSentinel

# You probably want to start from scratch when building the toolchain,
# so check if the temporary directory already exists, but only if the user asked for a build.
ifeq ($(IS_BUILDING),1)
  $(call verify_dir_does_not_exist,$(TOOLCHAIN_OBJ_DIR))
endif


# ------- Common C/C++ Compilation flags -------

# WARNING: The following components must be ABI compatible, which means they must be compiled
#          with similar CFLAGS:
# - newlib
#   Keep in mind that newlib's configure.host  may provide additional compilation flags.
#   The best thing to do is probably to run this makefile once and then look for the compilation flags
#   in the log output of some newlib source file like "strlen.c".
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

BINUTILS_VERSION := 2.28
BINUTILS_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/binutils-$(BINUTILS_VERSION)
BINUTILS_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/binutils-$(BINUTILS_VERSION)-obj
BINUTILS_TAR_FILE := binutils-$(BINUTILS_VERSION).tar.bz2

BINUTILS_UNTAR_SENTINEL := $(BINUTILS_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
BINUTILS_MAKEFILE := $(BINUTILS_OBJ_DIR)/Makefile
BINUTILS_MAKE_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
BINUTILS_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)BinutilsInstallSentinel


# ------- GMP lib flags -------

GMP_VERSION := 6.1.2
GMP_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/gmp-$(GMP_VERSION)
GMP_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gmp-$(GMP_VERSION)-obj
GMP_TAR_FILE := gmp-$(GMP_VERSION).tar.bz2

GMP_UNTAR_SENTINEL := $(GMP_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
GMP_MAKEFILE := $(GMP_OBJ_DIR)/Makefile
GMP_MAKE_SENTINEL := $(GMP_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
GMP_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)GmpInstallSentinel


# ------- MPFR lib flags -------

MPFR_VERSION := 3.1.5
MPFR_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/mpfr-$(MPFR_VERSION)
MPFR_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/mpfr-$(MPFR_VERSION)-obj
MPFR_TAR_FILE := mpfr-$(MPFR_VERSION).tar.xz

MPFR_UNTAR_SENTINEL := $(MPFR_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
MPFR_MAKEFILE := $(MPFR_OBJ_DIR)/Makefile
MPFR_MAKE_SENTINEL := $(MPFR_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
MPFR_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)MpfrInstallSentinel


# ------- MPC lib flags -------

MPC_VERSION := 1.0.3
MPC_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/mpc-$(MPC_VERSION)
MPC_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/mpc-$(MPC_VERSION)-obj
MPC_TAR_FILE := mpc-$(MPC_VERSION).tar.gz

MPC_UNTAR_SENTINEL := $(MPC_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
MPC_MAKEFILE := $(MPC_OBJ_DIR)/Makefile
MPC_MAKE_SENTINEL := $(MPC_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
MPC_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)MpcInstallSentinel


# ------- GCC flags -------

# This enables building a debug version of GCC in phase 2, instead of a release version,
# which is only useful if you need to debug GCC itself.

GCC_ENABLE_DEBUG_BUILD := 0

ifeq ($(GCC_ENABLE_DEBUG_BUILD),1)
  GCC_DEBUG_BUILD_FLAGS := CFLAGS="-O0 -g"  CXXFLAGS="-O0 -g"
else
  GCC_DEBUG_BUILD_FLAGS :=
endif

GCC_VERSION := 6.3.0
GCC_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/gcc-$(GCC_VERSION)
GCC_TAR_FILE := gcc-$(GCC_VERSION).tar.bz2
GCC_UNTAR_SENTINEL := $(GCC_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel

GCC1_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gcc-$(GCC_VERSION)-obj-phase1
GCC1_MAKEFILE := $(GCC1_OBJ_DIR)/Makefile
GCC1_MAKE_SENTINEL := $(GCC1_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)Make1Sentinel
GCC1_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)Gcc1InstallSentinel

GCC2_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gcc-$(GCC_VERSION)-obj-phase2
GCC2_MAKEFILE := $(GCC2_OBJ_DIR)/Makefile
GCC2_MAKE_SENTINEL := $(GCC2_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)Make2Sentinel
GCC2_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)Gcc2InstallSentinel

GCC_CFLAGS := $(COMMON_CFLAGS)
# GCC_CFLAGS += -H  # Print the name of each header file included, useful during development of this makefile.

COMMON_GCC_OPTIONS :=
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

  ifneq "$(or $(IS_GCC_4_9_X), $(IS_GCC_5_X), $(IS_GCC_6_X))" ""
    # The patch for version 5.3.0 works in the following versions too: 4.9.x, 5.x, 6.x.
    GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME := $(THIS_MAKEFILE_DIR)/GccDisableCppExceptionEmergencyBuffer-GCC-5.3.0.patch
  else
    $(error Unknown GCC version)
  endif

else

  GCC_DISABLE_CPP_EXCEPTION_EMERGENCY_BUFFER_PATCH_FILENAME := this-patch-filename-should-not-be-used

endif


# ------- Newlib flags -------

NEWLIB_VERSION := 2.5.0.20170421
NEWLIB_TAR_FILE := newlib-$(NEWLIB_VERSION).tar.gz
NEWLIB_UNTAR_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)
NEWLIB_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)
NEWLIB_NEWLIB_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)-obj

NEWLIB_UNTAR_SENTINEL := $(NEWLIB_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
NEWLIB_NEWLIB_MAKEFILE := $(NEWLIB_NEWLIB_OBJ_DIR)/Makefile
NEWLIB_NEWLIB_MAKE_SENTINEL := $(NEWLIB_NEWLIB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
NEWLIB_NEWLIB_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)NewlibNewlibInstallSentinel

NEWLIB_SMALLER_ASSERT_H_PATCH_FILENAME := $(THIS_MAKEFILE_DIR)/NewlibSmallerAssert.patch
NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME := $(THIS_MAKEFILE_DIR)/NewlibRemoveStrerrorMessages.patch

# NOTE: Newlib's switch --enable-target-optspace would add "-g -Os" to the compilation flags, but we have already done that in $(COMMON_CFLAGS)
NEWLIB_CFLAGS := $(COMMON_CFLAGS)

# Newlib's standard assert() implementation ends up calling fiprintf(), which pulls in loads of C runtime I/O functions,
# and we don't want that in our memory-constrained embedded environment.
NEWLIB_CFLAGS += -DHAVE_ASSERT_FUNC


# ------- GDB flags -------

GDB_VERSION := 7.12.1
GDB_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/gdb-$(GDB_VERSION)
GDB_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gdb-$(GDB_VERSION)-obj
GDB_TAR_FILE := gdb-$(GDB_VERSION).tar.xz

GDB_UNTAR_SENTINEL := $(GDB_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
GDB_MAKEFILE := $(GDB_OBJ_DIR)/Makefile
GDB_MAKE_SENTINEL := $(GDB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
GDB_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)GdbInstallSentinel


# ----------------- Create the directory where the toolchain build files (object files, etc) will land -----------------

$(TOOLCHAIN_OBJ_DIR_SENTINEL):
	if [ -d "$(CROSS_TOOLCHAIN_DIR)" ]; then echo "Directory \"$(CROSS_TOOLCHAIN_DIR)\" must not exist when building the toolchain from scratch. Otherwise you may end up with a mixture of old and new files." && false; fi && \
	echo "Creating directory \"$(TOOLCHAIN_OBJ_DIR)\"..." && \
	mkdir -p "$(TOOLCHAIN_OBJ_DIR)" && \
	echo "Creation of directory \"$(TOOLCHAIN_OBJ_DIR)\" finished." >"$(TOOLCHAIN_OBJ_DIR_SENTINEL)"

# ----------------- Build Binutils -----------------

$(BINUTILS_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(BINUTILS_TAR_FILE) ..." && \
	if [ -d "$(BINUTILS_SRC_DIR)" ]; then rm -rf "$(BINUTILS_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(BINUTILS_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking binutils finished." >"$(BINUTILS_UNTAR_SENTINEL)" && \
	echo "Unpacking binutils finished."

$(BINUTILS_MAKEFILE): $(BINUTILS_UNTAR_SENTINEL)
	echo "Configuring binutils from $(BINUTILS_SRC_DIR)/ to $(BINUTILS_OBJ_DIR)" && \
	if [ -d "$(BINUTILS_OBJ_DIR)" ]; then rm -rf "$(BINUTILS_OBJ_DIR)"; fi && \
	mkdir -p "$(BINUTILS_OBJ_DIR)" && \
	pushd "$(BINUTILS_OBJ_DIR)" >/dev/null && \
	$(BINUTILS_SRC_DIR)/configure --help && \
	$(BINUTILS_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	  --target=$(ARM_TARGET) \
	  --disable-nls && \
	popd >/dev/null && \
	echo "The binutils config has finished."

$(BINUTILS_MAKE_SENTINEL): $(BINUTILS_MAKEFILE)
	echo "Building binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(BINUTILS_OBJ_DIR)" && \
	echo "The binutils build has finished." >"$(BINUTILS_MAKE_SENTINEL)" && \
	echo "The binutils build has finished."

$(BINUTILS_INSTALL_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo "Installing binutils ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(BINUTILS_OBJ_DIR)" install && \
	echo "The binutils install has finished." >"$(BINUTILS_INSTALL_SENTINEL)" && \
	echo "The binutils install has finished."


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
	mkdir -p "$(GMP_OBJ_DIR)" && \
	pushd "$(GMP_OBJ_DIR)" >/dev/null && \
	$(GMP_SRC_DIR)/configure --help && \
	$(GMP_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The GMP config has finished."

$(GMP_MAKE_SENTINEL): $(GMP_MAKEFILE)
	echo "Building GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GMP_OBJ_DIR)" && \
	echo "The GMP build has finished." >"$(GMP_MAKE_SENTINEL)" && \
	echo "The GMP build has finished."

$(GMP_INSTALL_SENTINEL): $(GMP_MAKE_SENTINEL)
	echo "Installing GMP ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GMP_OBJ_DIR)" install && \
	echo "The GMP install has finished." >"$(GMP_INSTALL_SENTINEL)" && \
	echo "The GMP install has finished."


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
	mkdir -p "$(MPFR_OBJ_DIR)" && \
	pushd "$(MPFR_OBJ_DIR)" >/dev/null && \
	$(MPFR_SRC_DIR)/configure --help && \
	$(MPFR_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	  --with-gmp="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The MPFR config has finished."

$(MPFR_MAKE_SENTINEL): $(MPFR_MAKEFILE)
	echo "Building MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPFR_OBJ_DIR)" && \
	echo "The MPFR build has finished." >"$(MPFR_MAKE_SENTINEL)" && \
	echo "The MPFR build has finished."

$(MPFR_INSTALL_SENTINEL): $(MPFR_MAKE_SENTINEL)
	echo "Installing MPFR ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPFR_OBJ_DIR)" install && \
	echo "The MPFR install has finished." >"$(MPFR_INSTALL_SENTINEL)" && \
	echo "The MPFR install has finished."


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
	mkdir -p "$(MPC_OBJ_DIR)" && \
	pushd "$(MPC_OBJ_DIR)" >/dev/null && \
	$(MPC_SRC_DIR)/configure --help && \
	$(MPC_SRC_DIR)/configure \
	  $(CONFIG_CACHE_OPTION)  \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	  --with-gmp="$(CROSS_TOOLCHAIN_DIR)" \
	  --with-mpfr="$(CROSS_TOOLCHAIN_DIR)" && \
	popd >/dev/null && \
	echo "The MPC config has finished."

$(MPC_MAKE_SENTINEL): $(MPC_MAKEFILE)
	echo "Building MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPC_OBJ_DIR)" && \
	echo "The MPC build has finished." >"$(MPC_MAKE_SENTINEL)" && \
	echo "The MPC build has finished."

$(MPC_INSTALL_SENTINEL): $(MPC_MAKE_SENTINEL)
	echo "Installing MPC ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(MPC_OBJ_DIR)" install && \
	echo "The MPC install has finished." >"$(MPC_INSTALL_SENTINEL)" && \
	echo "The MPC install has finished."


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
# the binutils tools under the --prefix directory,
# even if the PATH is not set.

ifeq ($(BUILD_GMP_MPFR_MPC),1)
  $(GCC1_MAKEFILE): $(MPC_INSTALL_SENTINEL)
endif

$(GCC1_MAKEFILE): $(GCC_UNTAR_SENTINEL) $(BINUTILS_INSTALL_SENTINEL)
	echo "Configuring GCC phase 1 from $(GCC_SRC_DIR)/ to $(GCC1_OBJ_DIR)" && \
	if [ -d "$(GCC1_OBJ_DIR)" ]; then rm -rf "$(GCC1_OBJ_DIR)"; fi && \
	mkdir -p "$(GCC1_OBJ_DIR)" && \
	pushd "$(GCC1_OBJ_DIR)" >/dev/null && \
	$(GCC_SRC_DIR)/configure --help && \
	PATH=$(PATH_DIR):$$PATH \
      $(GCC_SRC_DIR)/configure \
        --enable-languages=c \
        --without-headers \
        $(COMMON_GCC_OPTIONS) && \
	popd >/dev/null && \
	echo "The GCC phase 1 config has finished."

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
    echo "The GCC phase 1 install has finished." >"$(GCC1_INSTALL_SENTINEL)" && \
    echo "The GCC phase 1 install has finished."


# ----------------- Build Newlib -----------------

$(NEWLIB_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(NEWLIB_TAR_FILE) ..." && \
	if [ -d "$(NEWLIB_UNTAR_DIR)" ]; then rm -rf "$(NEWLIB_UNTAR_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfa "$(TARBALLS_DOWNLOAD_DIR)/$(NEWLIB_TAR_FILE)" && \
	popd >/dev/null && \
	pushd "$(NEWLIB_SRC_DIR)" >/dev/null && \
	if [ $(USE_SMALLER_ASSERT) -ne 0 ]; then \
	  echo "Applying patch \"$(NEWLIB_SMALLER_ASSERT_H_PATCH_FILENAME)\" ..." && \
	  patch -p0 --forward <"$(NEWLIB_SMALLER_ASSERT_H_PATCH_FILENAME)"; \
	fi && \
	if [ $(REMOVE_STRERROR_MESSAGES) -ne 0 ]; then \
	  echo "Applying patch \"$(NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME)\" ..." && \
	  patch -p0 --forward <"$(NEWLIB_REMOVE_STRERROR_MESSAGES_PATCH_FILENAME)"; \
	fi && \
	popd >/dev/null && \
	echo "Unpacking newlib finished." >"$(NEWLIB_UNTAR_SENTINEL)" && \
	echo "Unpacking newlib finished."

NEWLIB_CFG_FLAGS :=

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
NEWLIB_CFG_FLAGS += --enable-newlib-nano-malloc  # With newlib's standard malloc library, you get an array in RAM called __malloc_av_ that weighs 1032 bytes, at least on a Cortex-M3 CPU.
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
	echo "About to configure newlib from $(NEWLIB_SRC_DIR)/ to $(NEWLIB_NEWLIB_OBJ_DIR)" && \
	if [ -d "$(NEWLIB_NEWLIB_OBJ_DIR)" ]; then rm -rf "$(NEWLIB_NEWLIB_OBJ_DIR)"; fi && \
	mkdir -p "$(NEWLIB_NEWLIB_OBJ_DIR)" && \
	pushd "$(NEWLIB_NEWLIB_OBJ_DIR)" >/dev/null && \
	echo "Help text from 'configure' script for top-level newlib dir (see further below for newlib/ subdir):" && \
	$(NEWLIB_SRC_DIR)/configure --help && \
	echo "Help text from 'configure' script for newlib/ subdir:" && \
	$(NEWLIB_SRC_DIR)/newlib/configure --help && \
	echo "Configuring newlib:" && \
	PATH=$(PATH_DIR):$$PATH \
          CFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" CXXFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" \
          $(NEWLIB_SRC_DIR)/configure \
            $(NEWLIB_CFG_FLAGS) && \
	popd >/dev/null && \
	echo "The binutils config has finished."

$(NEWLIB_NEWLIB_MAKE_SENTINEL): $(NEWLIB_NEWLIB_MAKEFILE)
	echo "Building newlib ..." && \
    $(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(NEWLIB_NEWLIB_OBJ_DIR)"  && \
    echo "The newlib build has finished." >"$(NEWLIB_NEWLIB_MAKE_SENTINEL)" && \
    echo "The newlib build has finished."

$(NEWLIB_NEWLIB_INSTALL_SENTINEL): $(NEWLIB_NEWLIB_MAKE_SENTINEL)
	echo "Installing newlib ..." && \
    $(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(NEWLIB_NEWLIB_OBJ_DIR)" install && \
    echo "The newlib install has finished." >"$(NEWLIB_NEWLIB_INSTALL_SENTINEL)" && \
    echo "The newlib install has finished."


# ----------------- GCC phase 2 -----------------

# Note that GCC's ./configure script will find at least some of
# the binutils tools under the --prefix directory,
# even if the PATH is not set.
$(GCC2_MAKEFILE): $(GCC_UNTAR_SENTINEL) $(NEWLIB_NEWLIB_INSTALL_SENTINEL)
	echo "Configuring GCC phase 2 from $(GCC_SRC_DIR)/ to $(GCC2_OBJ_DIR)" && \
    if [ -d "$(GCC2_OBJ_DIR)" ]; then rm -rf "$(GCC2_OBJ_DIR)"; fi && \
    mkdir -p "$(GCC2_OBJ_DIR)" && \
    pushd "$(GCC2_OBJ_DIR)" >/dev/null && \
    PATH=$(PATH_DIR):$$PATH \
      $(GCC_SRC_DIR)/configure \
        $(GCC_DEBUG_BUILD_FLAGS) \
        --enable-languages=c,c++ \
        $(COMMON_GCC_OPTIONS) && \
    popd >/dev/null && \
    echo "The GCC phase 2 config has finished."

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
      $(MAKE) -C "$(GCC2_OBJ_DIR)" install && \
    echo "The GCC phase 2 install has finished." >"$(GCC2_INSTALL_SENTINEL)" && \
    echo "The GCC phase 2 install has finished."


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

$(GDB_UNTAR_SENTINEL): $(GCC2_INSTALL_SENTINEL)
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
	mkdir -p "$(GDB_OBJ_DIR)" && \
	pushd "$(GDB_OBJ_DIR)" >/dev/null && \
	$(GDB_SRC_DIR)/configure --help && \
	PATH=$(PATH_DIR):$$PATH \
	  $(GDB_SRC_DIR)/configure \
	    $(GDB_DEBUG_BUILD_FLAGS) \
	    $(CONFIG_CACHE_OPTION)  \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --target=$(ARM_TARGET) && \
	popd >/dev/null && \
	echo "The GDB config has finished."

$(GDB_MAKE_SENTINEL): $(GDB_MAKEFILE)
	echo "Building GDB ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GDB_OBJ_DIR)" && \
	echo "The GDB build has finished." >"$(GDB_MAKE_SENTINEL)" && \
	echo "The GDB build has finished."

$(GDB_INSTALL_SENTINEL): $(GDB_MAKE_SENTINEL)
	echo "Installing GDB ..." && \
	$(EXPORT_SELECTED_FLAGS_IN_MAKEFLAGS) && \
	$(MAKE) -C "$(GDB_OBJ_DIR)" install && \
	echo "The GDB install has finished." >"$(GDB_INSTALL_SENTINEL)" && \
	echo "The GDB install has finished."


# --------------- Top-level rules ---------------

.PHONY: $(TARGET_NAME_ALL) $(TARGET_NAME_HELP) $(TARGET_NAME_CLEAN) $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_INTERNET) $(TARGET_NAME_DOWNLOAD_TARBALLS_FROM_FILE_SERVER)


.DEFAULT_GOAL := help

$(TARGET_NAME_HELP):
	@echo
	@echo "This makefile builds a GCC/newlib toolchain for a 'bare metal' programming environment for the Arduino Due."
	@echo "Other CPUs are supported, search for TOOLCHAIN_TARGET_CPU in the makefile for details."
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
	@echo "2) Set variable CROSS_TOOLCHAIN_DIR to some target directory of your choice where"
	@echo "   the toolchain will be placed. For example: export CROSS_TOOLCHAIN_DIR=\"\$$HOME/my-new-toolchain\""
	@echo "   Alternatively, you can set this variable as a make argument, see below for an example."
	@echo
	@echo "3) Optionally set variable ENABLE_DEBUG_TOOLCHAIN to '1' in order to build a debug toolchain."
	@echo "   This enables debug code in newlib's malloc implementation, for example."
	@echo "   You can compile debug builds with a non-debug toolchain, but the libraries that the toolchain"
	@echo "   provides (such as newlib) will be linked in as non-debug versions."
	@echo
	@echo "4) Optionally set variable CROSS_TOOLCHAIN_BUILD_DIR to some directory of your choice where"
	@echo "   all source and object files will be generated during the toolchain build process."
	@echo "   By default, these build files are placed in a subdirectory called \"Tmp\". That name is"
	@echo "   intuitive enough. I normally have such \"Tmp\" directories listed in my .gitignore files,"
	@echo "   and I tend to skip anything called \"Tmp\" when doing recursive greps."
	@echo "   You may want to name this directory differently or to place it somewhere else,"
	@echo "   perhaps next to the final toolchain bin (installation) directory. If you keep all sources"
	@echo "   used to build the toolchain, you will be able to step into the C runtime library and so on"
	@echo "   with a debugger like GDB."
	@echo
	@echo "5) Install any packages that GCC needs to build itself, like the GMP, MPFR, MPC and ELF libraries."
	@echo "   You will probably need to install the 'devel' versions of those packages. You will normally "
	@echo "   find such libraries in your Linux distribution's repository."
	@echo
	@echo "6) If you have already run this makefile in the past, you will have to delete or rename"
	@echo "   the Tmp subdirectory beforehand. Alternatively, run this makefile for target 'clean'."
	@echo
	@echo "The recommended way to run this makefile is:"
	@echo "  make  --no-builtin-variables --warn-undefined-variables  -j \"\$$(( \$$(getconf _NPROCESSORS_ONLN) + 1 ))\"  $(TARGET_NAME_ALL)"
	@echo "For GNU Make version 4.0 or above, option '--output-sync=target' is recommended."
	@echo "You can set optional variables inside the command above like this:"
	@echo "  make  TOOLCHAIN_TARGET_CPU=cortex-m4f  ENABLE_DEBUG_TOOLCHAIN=1  ...etc..."
	@echo

$(TARGET_NAME_ALL): $(GDB_INSTALL_SENTINEL)
	@echo "Toolchain installed in \"$(CROSS_TOOLCHAIN_DIR)\"."
	@if [ $(SHOULD_WARN_ABOUT_REBUILDING_SOFTWARE) -ne 0 ]; then \
	echo "WARNING: After a toolchain change you should rebuild all target software from scratch." ; \
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

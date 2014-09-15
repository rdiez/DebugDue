
# Run "make help" for information about how to use this makefile.

.DELETE_ON_ERROR:

SHELL := bash  # This makefile has only been tested with bash.

# ------- User Configuration -------

# Setting ENABLE_DEBUG_TOOLCHAIN to '1' builds the toolchain with -DDEBUG, which enables debug code at least
# in newlib's malloc implementation, and probably in other places too.
#
# It would be best to build both the debug and non-debug library versions, and that's probably what
# GCC's "multilib" support is all about, but I haven't figured it out yet.

ifeq ($(origin ENABLE_DEBUG_TOOLCHAIN), undefined)
  ENABLE_DEBUG_TOOLCHAIN := 0
endif

ifeq ($(origin TOOLCHAIN_TARGET_CPU), undefined)
  TOOLCHAIN_TARGET_CPU := cortex-m3
endif


# ------- Miscellaneous definitions -------

verify_variable_is_defined = $(if $(filter undefined,$(origin $(1))),$(error "The variable '$(1)' is not defined, but it should be at this point."))
verify_dir_does_not_exist = $(if $(shell if [ -d "$(1)" ]; then echo exists; fi),$(error Directory "$(1)" already exists, but it should not at this point.))

ARM_TARGET := arm-none-eabi

SENTINEL_FILENAME_PREFIX := ToolchainBuilder-


# Targets 'help' and 'clean' do not build, all other targets (usually 'all') do build.
TARGET_NAME_HELP := help
TARGET_NAME_CLEAN := clean
TARGET_NAME_DOWNLOAD_TARBALLS := download-tarballs
ifeq ($(strip $(MAKECMDGOALS)),)
  # The default target is 'help'
  IS_BUILDING := 0
else ifneq ($(filter $(TARGET_NAME_HELP), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
else ifneq ($(filter $(TARGET_NAME_CLEAN), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
else ifneq ($(filter $(TARGET_NAME_DOWNLOAD_TARBALLS), $(MAKECMDGOALS)),)
  IS_BUILDING := 0
else
  IS_BUILDING := 1
endif

# Check if variable CROSS_TOOLCHAIN_DIR is set, but only if the user asked for a build.
ifeq ($(IS_BUILDING),1)
  $(call verify_variable_is_defined,CROSS_TOOLCHAIN_DIR)
  PATH_DIR := $(CROSS_TOOLCHAIN_DIR)/bin
endif

THIS_MAKEFILE_DIR := $(shell readlink -f "$(CURDIR)")
TAR_FILES_DIR := $(THIS_MAKEFILE_DIR)/Tarballs


# ------- Build directory definitions -------

TOOLCHAIN_OBJ_DIR := $(THIS_MAKEFILE_DIR)/Tmp

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
  COMMON_CFLAGS += -g -O3
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

ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m3)
  COMMON_CFLAGS += -mcpu=cortex-m3 -mthumb
  GCC_FLOATING_POINT_FLAGS := --without-fp --with-float=soft
else ifeq ($(TOOLCHAIN_TARGET_CPU), cortex-m4f)
  COMMON_CFLAGS += -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard
  GCC_FLOATING_POINT_FLAGS := # No flags needed here.
else
  $(error Variable TOOLCHAIN_TARGET_CPU has invalid value "$(TOOLCHAIN_TARGET_CPU)")
endif

ifeq ($(IS_BUILDING),1)
  $(info Building toolchain for CPU: $(TOOLCHAIN_TARGET_CPU).)
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

BINUTILS_VERSION := 2.24
BINUTILS_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/binutils-$(BINUTILS_VERSION)
BINUTILS_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/binutils-$(BINUTILS_VERSION)-obj
BINUTILS_TAR_FILE := binutils-$(BINUTILS_VERSION).tar.bz2

BINUTILS_UNTAR_SENTINEL := $(BINUTILS_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
BINUTILS_MAKEFILE := $(BINUTILS_OBJ_DIR)/Makefile
BINUTILS_MAKE_SENTINEL := $(BINUTILS_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
BINUTILS_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)BinutilsInstallSentinel


# ------- GCC flags -------

GCC_VERSION := 4.8.2
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
COMMON_GCC_OPTIONS += --config-cache
COMMON_GCC_OPTIONS += --prefix="$(CROSS_TOOLCHAIN_DIR)"

COMMON_GCC_OPTIONS += --target=$(ARM_TARGET)
COMMON_GCC_OPTIONS += $(GCC_FLOATING_POINT_FLAGS)

COMMON_GCC_OPTIONS += --disable-nls
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
COMMON_GCC_OPTIONS += --disable-libstdcxx-verbose
COMMON_GCC_OPTIONS += --with-gnu-ld --with-gnu-as

COMMON_GCC_OPTIONS += --enable-lto  # This flag is probably only required in GCC phase 2.


# ------- Newlib flags -------

NEWLIB_VERSION := 2.1.0
NEWLIB_TAR_FILE := newlib-$(NEWLIB_VERSION).tar.gz
NEWLIB_UNTAR_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)
NEWLIB_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)
NEWLIB_NEWLIB_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/newlib-$(NEWLIB_VERSION)-obj

NEWLIB_UNTAR_SENTINEL := $(NEWLIB_SRC_DIR)/$(SENTINEL_FILENAME_PREFIX)UntarSentinel
NEWLIB_NEWLIB_MAKEFILE := $(NEWLIB_NEWLIB_OBJ_DIR)/Makefile
NEWLIB_NEWLIB_MAKE_SENTINEL := $(NEWLIB_NEWLIB_OBJ_DIR)/$(SENTINEL_FILENAME_PREFIX)MakeSentinel
NEWLIB_NEWLIB_INSTALL_SENTINEL := $(CROSS_TOOLCHAIN_DIR)/$(SENTINEL_FILENAME_PREFIX)NewlibNewlibInstallSentinel

# NOTE: Newlib's switch --enable-target-optspace would add "-g -Os" to the compilation flags, but we have already done that in $(COMMON_CFLAGS)
NEWLIB_CFLAGS := $(COMMON_CFLAGS)

# Newlib's standard assert() implementation ends up calling fiprintf(), which pulls in loads of C runtime I/O functions,
# and we don't want that in our memory-constrained embedded environment.
NEWLIB_CFLAGS += -DHAVE_ASSERT_FUNC


# ------- GDB flags -------

GDB_VERSION := 7.6.2
GDB_SRC_DIR := $(TOOLCHAIN_OBJ_DIR)/gdb-$(GDB_VERSION)
GDB_OBJ_DIR := $(TOOLCHAIN_OBJ_DIR)/gdb-$(GDB_VERSION)-obj
GDB_TAR_FILE := gdb-$(GDB_VERSION).tar.bz2

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
	tar xfj "$(TAR_FILES_DIR)/$(BINUTILS_TAR_FILE)" && \
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
	  --config-cache \
	  --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	  --target=$(ARM_TARGET) \
	  --disable-nls && \
	popd >/dev/null && \
	echo "The binutils config has finished."

$(BINUTILS_MAKE_SENTINEL): $(BINUTILS_MAKEFILE)
	echo "Building binutils ..." && \
	export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
	$(MAKE) -C "$(BINUTILS_OBJ_DIR)" && \
	echo "The binutils build has finished." >"$(BINUTILS_MAKE_SENTINEL)" && \
	echo "The binutils build has finished."

$(BINUTILS_INSTALL_SENTINEL): $(BINUTILS_MAKE_SENTINEL)
	echo "Installing binutils ..." && \
	export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
	$(MAKE) -C "$(BINUTILS_OBJ_DIR)" install && \
	echo "The binutils install has finished." >"$(BINUTILS_INSTALL_SENTINEL)" && \
	echo "The binutils install has finished."


# ----------------- GCC phase 1 -----------------

$(GCC_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(GCC_TAR_FILE) ..." && \
	if [ -d "$(GCC_SRC_DIR)" ]; then rm -rf "$(GCC_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfj "$(TAR_FILES_DIR)/$(GCC_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking GCC finished." >"$(GCC_UNTAR_SENTINEL)" && \
	echo "Unpacking GCC finished."

# Note that GCC's ./configure script will find at least some of
# the binutils tools under the --prefix directory,
# even if the PATH is not set.
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
    export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC1_OBJ_DIR)" all-gcc && \
    echo "The GCC phase 1 build has finished." >"$(GCC1_MAKE_SENTINEL)" && \
    echo "The GCC phase 1 build has finished."

$(GCC1_INSTALL_SENTINEL): $(GCC1_MAKE_SENTINEL)
	echo "Installing GCC phase 1 ..." && \
    export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC1_OBJ_DIR)" install-gcc && \
    echo "The GCC phase 1 install has finished." >"$(GCC1_INSTALL_SENTINEL)" && \
    echo "The GCC phase 1 install has finished."


# ----------------- Build Newlib -----------------

$(NEWLIB_UNTAR_SENTINEL): $(TOOLCHAIN_OBJ_DIR_SENTINEL)
	echo "Unpacking $(NEWLIB_TAR_FILE) ..." && \
	if [ -d "$(NEWLIB_UNTAR_DIR)" ]; then rm -rf "$(NEWLIB_UNTAR_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfz "$(TAR_FILES_DIR)/$(NEWLIB_TAR_FILE)" && \
	popd >/dev/null && \
	echo "Unpacking newlib finished." >"$(NEWLIB_UNTAR_SENTINEL)" && \
	echo "Unpacking newlib finished."

NEWLIB_CFG_FLAGS :=

NEWLIB_CFG_FLAGS += --prefix="$(CROSS_TOOLCHAIN_DIR)"
NEWLIB_CFG_FLAGS += --target=$(ARM_TARGET)
NEWLIB_CFG_FLAGS += --config-cache
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
	echo "Configuring newlib from $(NEWLIB_SRC_DIR)/ to $(NEWLIB_NEWLIB_OBJ_DIR)" && \
	if [ -d "$(NEWLIB_NEWLIB_OBJ_DIR)" ]; then rm -rf "$(NEWLIB_NEWLIB_OBJ_DIR)"; fi && \
	mkdir -p "$(NEWLIB_NEWLIB_OBJ_DIR)" && \
	pushd "$(NEWLIB_NEWLIB_OBJ_DIR)" >/dev/null && \
	$(NEWLIB_SRC_DIR)/configure --help && \
	PATH=$(PATH_DIR):$$PATH \
      CFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" CXXFLAGS_FOR_TARGET="$(NEWLIB_CFLAGS)" \
      $(NEWLIB_SRC_DIR)/configure \
        $(NEWLIB_CFG_FLAGS) && \
	popd >/dev/null && \
	echo "The binutils config has finished."

$(NEWLIB_NEWLIB_MAKE_SENTINEL): $(NEWLIB_NEWLIB_MAKEFILE)
	echo "Building newlib ..." && \
    export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(NEWLIB_NEWLIB_OBJ_DIR)"  && \
    echo "The newlib build has finished." >"$(NEWLIB_NEWLIB_MAKE_SENTINEL)" && \
    echo "The newlib build has finished."

$(NEWLIB_NEWLIB_INSTALL_SENTINEL): $(NEWLIB_NEWLIB_MAKE_SENTINEL)
	echo "Installing newlib ..." && \
    export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
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
        --enable-languages=c,c++ \
        $(COMMON_GCC_OPTIONS) && \
    popd >/dev/null && \
    echo "The GCC phase 2 config has finished."

$(GCC2_MAKE_SENTINEL): $(GCC2_MAKEFILE)
	echo "Building GCC phase 2 ..." && \
    export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
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
    export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
    PATH=$(PATH_DIR):$$PATH \
      $(MAKE) -C "$(GCC2_OBJ_DIR)" install && \
    echo "The GCC phase 2 install has finished." >"$(GCC2_INSTALL_SENTINEL)" && \
    echo "The GCC phase 2 install has finished."


# ----------------- Build GDB -----------------

$(GDB_UNTAR_SENTINEL): $(GCC2_INSTALL_SENTINEL)
	echo "Unpacking $(GDB_TAR_FILE) ..." && \
	if [ -d "$(GDB_SRC_DIR)" ]; then rm -rf "$(GDB_SRC_DIR)"; fi && \
	pushd "$(TOOLCHAIN_OBJ_DIR)" >/dev/null && \
	tar xfj "$(TAR_FILES_DIR)/$(GDB_TAR_FILE)" && \
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
	    --config-cache \
	    --prefix="$(CROSS_TOOLCHAIN_DIR)" \
	    --target=$(ARM_TARGET) && \
	popd >/dev/null && \
	echo "The GDB config has finished."

$(GDB_MAKE_SENTINEL): $(GDB_MAKEFILE)
	echo "Building GDB ..." && \
	export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
	$(MAKE) -C "$(GDB_OBJ_DIR)" && \
	echo "The GDB build has finished." >"$(GDB_MAKE_SENTINEL)" && \
	echo "The GDB build has finished."

$(GDB_INSTALL_SENTINEL): $(GDB_MAKE_SENTINEL)
	echo "Installing GDB ..." && \
	export MAKEFLAGS="$(filter --jobserver-fds=%,$(MAKEFLAGS)) $(filter -j,$(MAKEFLAGS))" && \
	$(MAKE) -C "$(GDB_OBJ_DIR)" install && \
	echo "The GDB install has finished." >"$(GDB_INSTALL_SENTINEL)" && \
	echo "The GDB install has finished."


# --------------- Top-level rules ---------------

.PHONY: all clean help

.DEFAULT_GOAL := help

$(TARGET_NAME_HELP):
	@echo
	@echo "This makefile builds a GCC/newlib toolchain for a 'bare metal' programming environment for the Arduino Due."
	@echo "Other CPUs are supported, search for TOOLCHAIN_TARGET_CPU in the makefile for details."
	@echo
	@echo "Before building the toolchain with this makefile, you need to do the following:"
	@echo
	@echo "1) Run this makefile for target '$(TARGET_NAME_DOWNLOAD_TARBALLS)'. Alternatively,"
	@echo "   manually download the following files and place them in the Tarballs subdirectory:"
	@echo "     $(BINUTILS_TAR_FILE)"
	@echo "     $(GCC_TAR_FILE)"
	@echo "     $(NEWLIB_TAR_FILE)"
	@echo "     $(GDB_TAR_FILE)"
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
	@echo "4) Install any packages that GCC needs to build itself, like the GMP, MPFR, MPC and ELF libraries."
	@echo "   You will probably need to install the 'devel' versions of those packages. You will normally "
	@echo "   find such libraries in your Linux distribution's repository."
	@echo
	@echo "5) If you have already run this makefile in the past, you will have to delete"
	@echo "   the Tmp subdirectory beforehand."
	@echo
	@echo "The recommended way to run this makefile is:"
	@echo "  make  --no-builtin-variables --warn-undefined-variables  -j \$$(( \$$(getconf _NPROCESSORS_ONLN) + 1 ))  all"
	@echo "You can set optional variables like this:"
	@echo "  make  TOOLCHAIN_TARGET_CPU=cortex-m4f  ENABLE_DEBUG_TOOLCHAIN=1  ...etc..."
	@echo

all: $(GDB_INSTALL_SENTINEL)
	echo "Toolchain installed in $(CROSS_TOOLCHAIN_DIR)"

# This 'clean' rule does not delete the toolchain bin directory (variable CROSS_TOOLCHAIN_DIR),
# the user has to delete it manually. I'm not sure whether that is a good idea or not,
# but a toolchain takes long to build and the user may want to save it in case the new one
# does not work correctly.
$(TARGET_NAME_CLEAN):
	@echo "Deleting directory \"$(TOOLCHAIN_OBJ_DIR)\"..." && \
	if [ -d "$(TOOLCHAIN_OBJ_DIR)" ]; then rm -rf "$(TOOLCHAIN_OBJ_DIR)"; fi && \
	echo "Finished. You may want to delete the toolchain directory you specified originally with variable CROSS_TOOLCHAIN_DIR."


GNU_MIRROR_BASE_URL := http://ftpmirror.gnu.org

$(TARGET_NAME_DOWNLOAD_TARBALLS):
	./DownloadTarball.sh "$(GNU_MIRROR_BASE_URL)/binutils/$(BINUTILS_TAR_FILE)"           "$(TAR_FILES_DIR)"
	./DownloadTarball.sh "$(GNU_MIRROR_BASE_URL)/gcc/gcc-$(GCC_VERSION)/$(GCC_TAR_FILE)"  "$(TAR_FILES_DIR)"
	./DownloadTarball.sh "$(GNU_MIRROR_BASE_URL)/gdb/$(GDB_TAR_FILE)"                     "$(TAR_FILES_DIR)"
	./DownloadTarball.sh "ftp://sourceware.org/pub/newlib/$(NEWLIB_TAR_FILE)"             "$(TAR_FILES_DIR)"
	@echo "Finished downloading tarballs."

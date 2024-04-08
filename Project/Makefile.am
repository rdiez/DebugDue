
# Copyright (C) 2012-2017 R. Diez - see the DebugDue project for licensing information.

AUTOMAKE_OPTIONS := foreign subdir-objects

.DELETE_ON_ERROR:


# ------------------------------------
# Global definitions.

ELF_BASENAME := firmware

ELF_FILENAME := firmware.elf  # Here substitution $(ELF_BASENAME) does not work (!?).

MAP_FILENAME := $(ELF_BASENAME).map

firmware_elf_LDADD :=


bin_PROGRAMS := $(ELF_FILENAME)

dist_data_DATA :=  # See "dist_data_DATA += ..." statements below.

noinst_LIBRARIES :=


# ------------------------------------
# Include paths.

# configure.ac has already set some of the include paths,
# so here we just add all the extra ones we need.

firmware_elf_CPPFLAGS := $(AM_CPPFLAGS)

firmware_elf_SOURCES :=


# ----- Bare Metal Support library, which I have written myself.

# Note that files NewlibSyscalls.cpp and crt0.cpp are missing here, see below.

if IS_QEMU_FIRMWARE

  firmware_elf_SOURCES += src/$(BOARD_SUPPORT_DIR)/AngelInterface.cpp

endif

if NEEDS_BARE_METAL

  firmware_elf_SOURCES += \
    src/BareMetalSupport/Miscellaneous.cpp \
    src/BareMetalSupport/MiscellaneousAsm.S \
    src/BareMetalSupport/IoUtils.cpp \
    src/BareMetalSupport/SerialPrint.cpp \
    src/BareMetalSupport/SerialPortAsyncTx.cpp \
    src/BareMetalSupport/TextParsingUtils.cpp \
    src/BareMetalSupport/GenericSerialConsole.cpp \
    src/BareMetalSupport/Uptime.cpp \
    src/BareMetalSupport/SysTickUtils.cpp \
    src/BareMetalSupport/BusyWait.cpp \
    src/BareMetalSupport/MainLoopSleep.cpp

  firmware_elf_SOURCES += \
    src/ArduinoDueUtils/ArduinoDueUtils.cpp

endif

firmware_elf_SOURCES += src/$(BOARD_SUPPORT_DIR)/BoardInit.cpp
firmware_elf_SOURCES += src/$(BOARD_SUPPORT_DIR)/AssertionUtils.cpp
firmware_elf_SOURCES += src/$(BOARD_SUPPORT_DIR)/DebugConsoleSupport.cpp

firmware_elf_SOURCES += src/BareMetalSupport/BoardInitUtils.cpp
firmware_elf_SOURCES += src/BareMetalSupport/DebugConsoleSerialSyncCommon.cpp
firmware_elf_SOURCES += src/BareMetalSupport/StackCheck.cpp
firmware_elf_SOURCES += src/BareMetalSupport/IntegerPrintUtils.cpp


if NEEDS_ATMEL_SOFTWARE_FRAMEWORK

  # Build the ASF into a separate library, so that you can adjust the compilation flags
  # just for the ASF files, for example, in order to selectively turn some compilation warnings off.
  noinst_LIBRARIES += libAtmelSoftwareFramework.a

  # Prevent the annoying warning:  ar: `u' modifier ignored since `D' is the default (see `U')
  # By default, Automake is using $(AR) $(ARFLAGS), and ARFLAGS defaults to "cru".
  # I reported this issue to the Autoconf project:
  #   sr #110476: ar: `u' modifier ignored since `D' is the default (see `U')
  #   https://savannah.gnu.org/support/index.php?110476
  # It turns out that this was an Automake issue, see Automate bug number 20082.
  # It has been fixed on 2023-11-21 with this commit:
  #   https://git.savannah.gnu.org/cgit/automake.git/commit/?h=8cdbdda5aec652c356fe6dbba96810202176ae75
  # When the information in this comment was last updated, there was no new Autoconf release yet with this fix.
  libAtmelSoftwareFramework_a_AR := $(AR) cr

  firmware_elf_LDADD += libAtmelSoftwareFramework.a

  libAtmelSoftwareFramework_a_CFLAGS := $(AM_CFLAGS)

  # We cannot realistically fix all warnings in the Atmel Software Library, so selectively turn some of them off.
  # If you encounter too many in the future, you could also turn all warnings off for this library.
  libAtmelSoftwareFramework_a_CFLAGS += -Wno-cast-qual -Wno-conversion -Wno-sign-conversion -Wno-expansion-to-defined

  libAtmelSoftwareFramework_a_CPPFLAGS := $(AM_CPPFLAGS)

  libAtmelSoftwareFramework_a_CPPFLAGS += $(ASF_INCLUDE_COMMON)


  libAtmelSoftwareFramework_a_SOURCES :=

  # ----- CMSIS library.

  libAtmelSoftwareFramework_a_SOURCES += \
    src/AsfSrc/sam/utils/cmsis/sam3x/source/templates/system_sam3x.c  # Only needed for SystemCoreClockUpdate().

  # ----- The ASF library comes from Atmel and has a very liberal license.

  libAtmelSoftwareFramework_a_SOURCES += \
     src/AsfSrc/sam/drivers/pmc/pmc.c \
     src/AsfSrc/sam/drivers/pio/pio.c \
     src/AsfSrc/sam/drivers/wdt/wdt.c \
     src/AsfSrc/sam/drivers/rstc/rstc.c \
     src/AsfSrc/sam/drivers/uart/uart.c \
     src/AsfSrc/common/utils/interrupt/interrupt_sam_nvic.c \
     src/AsfSrc/common/services/clock/sam3x/sysclk.c

if IS_DEBUG_DUE
  libAtmelSoftwareFramework_a_SOURCES += \
     src/AsfSrc/sam/drivers/pmc/sleep.c \
     src/AsfSrc/sam/drivers/adc/adc.c \
     src/AsfSrc/sam/drivers/uotghs/uotghs_device.c \
     src/AsfSrc/common/services/usb/class/cdc/device/udi_cdc.c \
     src/AsfSrc/common/services/usb/class/cdc/device/udi_cdc_desc.c \
     src/AsfSrc/common/services/usb/udc/udc.c
endif

endif


# ------------------------------------
# Project-specific files.

if IS_EMPTY_FIRMWARE

  firmware_elf_SOURCES += \
    src/EmptyFirmware/Main.cpp \
    src/EmptyFirmware/InterruptHandlers.cpp

endif

if IS_QEMU_FIRMWARE

  firmware_elf_SOURCES += src/QemuFirmware/Main.cpp
  firmware_elf_SOURCES += src/QemuFirmware/InterruptHandlers.cpp

endif

if IS_DEBUG_DUE

  firmware_elf_SOURCES += \
    src/JtagFirmware/Main.cpp \
    src/JtagFirmware/UsbSupport.cpp \
    src/JtagFirmware/Led.cpp \
    src/JtagFirmware/UsbConnection.cpp \
    src/JtagFirmware/UsbBuffers.cpp \
    src/JtagFirmware/BusPirateConnection.cpp \
    src/JtagFirmware/BusPirateConsole.cpp \
    src/JtagFirmware/BusPirateBinaryMode.cpp \
    src/JtagFirmware/BusPirateOpenOcdMode.cpp \
    src/JtagFirmware/CommandProcessor.cpp \
    src/JtagFirmware/SerialPortConsole.cpp \
    src/JtagFirmware/InterruptHandlers.cpp

endif


# ------------------------------------
# About file crt0.cpp :
#
# File "crt0.o" gets automatically added to the list of object files to link, but it is not
# not enough for file crt0.cpp to be compiled into some library. First of all, I do not think
# that the linker tries to find crt0.o in any user-supplied libraries. Secondly,
# we need to ensure that the object file is called exactly "crt0.o", without any
# automatically added prefix or suffix. This is why the following rule compiles crt0.cpp by hand.
# I asked the GCC developers to get rid of this nuisance to no avail:
#   Add -mno-crt0 to disable automatic crt0 injection
#   https://gcc.gnu.org/bugzilla/show_bug.cgi?id=68605

CRT0_SRC_FILENAME := $(BARE_METAL_SUPPORT_DIR)/crt0.cpp
CRT0_O_FILENAME := crt0.o
$(CRT0_O_FILENAME):
	echo "Compiling $(CRT0_SRC_FILENAME) to $(CRT0_O_FILENAME)..." && \
        $(CXX) $(AM_CPPFLAGS) $(AM_CXXFLAGS) $(CRT0_SRC_FILENAME) -c -o $(CRT0_O_FILENAME)


# ------------------------------------
# About file NewlibSyscalls.cpp :
#
# Newlib references syscalls like _sbrk(), but we have not provided them in Libgloss or else,
# see the toolchain makefile for more information.
#
# The problem is that normally a library provides stuff for others to use, but this time
# a library (Newlib) wants to use some routines (Newlib's syscalls) that other libraries provide.
# That is a kind of circular reference.
#
# When using Automake, it is hard to alter the order in which libraries are linked .
# To fix the circular reference problem, some people suggest --start-group, some others
# the usage of "convenience libraries", but I haven't managed to get it to work yet with Automake.
#
# In order to prevent linker errors because of newlib's syscalls, we compile file syscalls_sam3.c
# (or our own replacement) as part of the main project, which seems to do the trick.
#
# Another workaround could be to implement a new function in Newlib or Libgloss, so that our
# start-up code can call that function very early and pass pointers to all syscalls supplied.
#
# Therefore, your main project must compile NewlibSyscalls.cpp itself,
# instead of compiling it into some other library.

firmware_elf_SOURCES += src/BareMetalSupport/NewlibSyscalls.cpp


# ------------------------------------

# Make all sources recompile if this makefile changes. This will undoubtedly recompile
# too often, but it is the easiest and safest way I could find yet. Note that xxx_OBJECTS
# variables are not documented in the Automake manual, so they could change in the future.
# The way I have tested this is to change the project's version number in configure.ac
# and check that a new firmware binary with the new version number gets built automatically.
$(firmware_elf_OBJECTS): Makefile

LINKER_SCRIPT_FILENAME := $(abs_srcdir)/src/$(BOARD_SUPPORT_DIR)/flash.ld

# Note that the linking order specified in xxx_LDADD is important: if library libfoo.a has an undefined symbol,
# and that symbol is in libbar.a, you need to put libfoo.a before libbar.a on the command line.

firmware_elf_LDADD += $(CRT0_O_FILENAME)

firmware_elf_LDFLAGS := $(AM_LDFLAGS)

firmware_elf_LDFLAGS += -Wl,-T$(LINKER_SCRIPT_FILENAME)

firmware_elf_LDFLAGS += -Wl,--gc-sections
firmware_elf_LDFLAGS += -Wl,--warn-common
firmware_elf_LDFLAGS += -Wl,--sort-section=alignment  # Reduces the overall padding needed.

if !USE_GOLD_LINKER
  # The Gold linker does not support --warn-section-align , at least in Gold version 1.14 (bundled with GNU Binutils 2.28).
  firmware_elf_LDFLAGS += -Wl,--warn-section-align
endif

firmware_elf_LDFLAGS += -Wl,-Map,$(MAP_FILENAME)
firmware_elf_LDFLAGS += -Wl,--cref  # Output a cross reference table, which will land in the map file.

# Make sure that the vector table gets linked in by referencing the file that contains it.
# The entry point is used by GDB. Note that the CPU itself only looks at the vector table,
# so the entry point should match the reset vector.
firmware_elf_LDFLAGS += -Wl,--entry=BareMetalSupport_Reset_Handler

if USE_GOLD_LINKER
  firmware_elf_LDFLAGS += -fuse-ld=gold
endif

$(ELF_FILENAME): $(LINKER_SCRIPT_FILENAME)


# ------------------------------------
# Create and distribute the .bin file too.

# I haven't found any way to build and install the .bin file to the bin directory,
# but maybe the data dir is the 'right' place for it anyway.
dist_data_DATA += $(ELF_BASENAME).bin

$(ELF_BASENAME).bin: $(ELF_FILENAME)
	echo "Generating binary file \"$(abspath $@)\"..." && \
	$(TARGET_ARCH)-objcopy -O binary "$<" "$@"


# ------------------------------------
# Distribute the .map file too.

$(MAP_FILENAME): $(ELF_FILENAME)
	echo "This rule is empty, as the step to generate the .elf file also generates the map file." >/dev/null

dist_data_DATA += $(MAP_FILENAME)


# ------------------------------------
# Optionally disassemble and dump in various ways the generated .ELF file.

# POSSIBLE IMPROVEMENT: Automatically delete these files when recursive target "disassemble" is not specified.
# Otherwise, the contents of these files may be stale.
disassemble-local: $(ELF_BASENAME)-objects-sorted-by-size.map  $(ELF_BASENAME)-objdump-with-disassemble.asm  $(ELF_BASENAME)-sorted-strings.txt $(ELF_BASENAME)-readelf-dump.txt

# Create a list of objects in the ELF file sorted by size, which helps when trying to optimise the bin size.
$(ELF_BASENAME)-objects-sorted-by-size.map: $(ELF_FILENAME)
	echo "Generating object list sorted by size to \"$(abspath $@)\"..." && \
        $(TARGET_ARCH)-nm --radix=d --demangle --size-sort "$<" >"$@"

$(ELF_BASENAME)-objdump-with-disassemble.asm: $(ELF_FILENAME)
	echo "Dumping with disassemble to \"$(abspath $@)\"..." && \
        $(TARGET_ARCH)-objdump --demangle --all-headers --disassemble --source --wide  "$<" >"$@"

$(ELF_BASENAME)-readelf-dump.txt: $(ELF_FILENAME)
	echo "Generating readelf dump to \"$(abspath $@)\"..." && \
        $(TARGET_ARCH)-readelf --file-header --program-headers --section-headers --section-groups --section-details --symbols --version-info --arch-specific --wide  "$<" >"$@"

# Avoid using a pipe in the call to 'sort' below. Otherwise, we would have to enable bash option "set -o pipefail",
# assuming that the shell is Bash.
$(ELF_BASENAME)-sorted-strings.txt: $(ELF_BASENAME).bin
	echo "Extracting strings to \"$(abspath $@)\"..." && \
        $(TARGET_ARCH)-strings "$<" >"$(ELF_BASENAME)-unsorted-strings.txt" && \
        sort "$(ELF_BASENAME)-unsorted-strings.txt" >"$@"

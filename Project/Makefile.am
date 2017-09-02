
# Copyright (C) 2012-2017 R. Diez - see the JtagDue project for licensing information.

AUTOMAKE_OPTIONS := foreign subdir-objects

.DELETE_ON_ERROR:


# ------------------------------------
# Global definitions.

ELF_BASENAME := firmware

ELF_FILENAME := firmware.elf  # Here substitution $(ELF_BASENAME) does not work (!?).

bin_PROGRAMS := $(ELF_FILENAME)

dist_data_DATA :=  # See "dist_data_DATA += ..." statements below.

MAP_FILENAME := $(ELF_BASENAME).map


# ------------------------------------
# Include paths.

# configure.ac has already set some of the include paths,
# so here we just add all the extra ones we need.

firmware_elf_CPPFLAGS := $(AM_CPPFLAGS)

firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/drivers/pmc
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/drivers/pio
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/drivers/rstc
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/drivers/wdt
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/drivers/adc
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/drivers/uart
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/boards
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/boards
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/services/clock
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/services/sleepmgr
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/services/usb/class/cdc
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/services/usb/class/cdc/device
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/services/usb/udc
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/services/usb
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/utils/cmsis/sam3x/include
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/utils/cmsis/sam3x/source/templates
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/thirdparty/CMSIS/Include
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/utils
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/utils/preprocessor
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/sam/utils/header_files
firmware_elf_CPPFLAGS += -I$(srcdir)/AsfSrc/common/utils

firmware_elf_CPPFLAGS += -I$(BARE_METAL_SUPPORT_DIR)/..  # This is so that including a file like <BareMetalSupport/Miscellaneous.h>
                                                         # does find the files in $(BARE_METAL_SUPPORT_DIR).
                                                         # Not really ideal, but there are no header (*.h) files in $srcdir (hopefully).
firmware_elf_SOURCES :=


# ----- CMSIS library.

firmware_elf_SOURCES += \
    AsfSrc/sam/utils/cmsis/sam3x/source/templates/system_sam3x.c  # Only needed for SystemCoreClockUpdate().


# ----- Bare Metal Support library, which I have written myself.

# Note that files NewlibSyscalls.cpp and crt0.cpp are missing here, see below.

firmware_elf_SOURCES += \
    BareMetalSupport/AssertionUtils.cpp \
    BareMetalSupport/Miscellaneous.cpp \
    BareMetalSupport/MiscellaneousAsm.S \
    BareMetalSupport/IntegerPrintUtils.cpp \
    BareMetalSupport/IoUtils.cpp \
    BareMetalSupport/SerialPortUtils.cpp \
    BareMetalSupport/SerialPrint.cpp \
    BareMetalSupport/SerialPortAsyncTx.cpp \
    BareMetalSupport/BoardInit.cpp \
    BareMetalSupport/StackCheck.cpp \
    BareMetalSupport/TextParsingUtils.cpp \
    BareMetalSupport/GenericSerialConsole.cpp \
    BareMetalSupport/Uptime.cpp \
    BareMetalSupport/SysTickUtils.cpp \
    BareMetalSupport/BusyWait.cpp \
    BareMetalSupport/MainLoopSleep.cpp


# ----- The ASF library comes from Atmel and has a very liberal license.

firmware_elf_SOURCES += \
     AsfSrc/sam/drivers/pmc/pmc.c \
     AsfSrc/sam/drivers/pio/pio.c \
     AsfSrc/sam/drivers/wdt/wdt.c \
     AsfSrc/sam/drivers/rstc/rstc.c \
     AsfSrc/sam/drivers/uart/uart.c \
     AsfSrc/common/utils/interrupt/interrupt_sam_nvic.c \
     AsfSrc/common/services/clock/sam3x/sysclk.c


# ------------------------------------
# Project-specific files.

if IS_EMPTY_FIRMWARE

  firmware_elf_SOURCES += \
    EmptyFirmware/Main.cpp \
    EmptyFirmware/InterruptHandlers.cpp

  firmware_elf_CPPFLAGS += -I$(srcdir)/EmptyFirmware/ConfigFilesForAsf

endif


if IS_JTAG_DUE

  firmware_elf_SOURCES += \
     AsfSrc/sam/drivers/pmc/sleep.c \
     AsfSrc/sam/drivers/adc/adc.c \
     AsfSrc/sam/drivers/uotghs/uotghs_device.c \
     AsfSrc/common/services/usb/class/cdc/device/udi_cdc.c \
     AsfSrc/common/services/usb/class/cdc/device/udi_cdc_desc.c \
     AsfSrc/common/services/usb/udc/udc.c

  firmware_elf_SOURCES += \
    JtagFirmware/Main.cpp \
    JtagFirmware/UsbSupport.cpp \
    JtagFirmware/Led.cpp \
    JtagFirmware/UsbConnection.cpp \
    JtagFirmware/UsbBuffers.cpp \
    JtagFirmware/BusPirateConnection.cpp \
    JtagFirmware/BusPirateConsole.cpp \
    JtagFirmware/BusPirateBinaryMode.cpp \
    JtagFirmware/BusPirateOpenOcdMode.cpp \
    JtagFirmware/CommandProcessor.cpp \
    JtagFirmware/SerialPortConsole.cpp \
    JtagFirmware/InterruptHandlers.cpp

  firmware_elf_CPPFLAGS += -I$(srcdir)/JtagFirmware
  firmware_elf_CPPFLAGS += -I$(srcdir)/JtagFirmware/ConfigFilesForAsf

endif


# ------------------------------------
# About file crt0.cpp :
#
# File "crt0.o" gets automatically added to the list of object files to link, but it is not
# not enough for file crt0.cpp to be compiled into some library. First of all, I do not think
# that the linker tries to find crt0.o in any user-supplied libraries. Secondly,
# we need to ensure that the object file is called exactly "crt0.o", without any
# automatically added prefix or suffix. This is why the following rule compiles crt0.cpp by hand.

CRT0_SRC_FILENAME := $(BARE_METAL_SUPPORT_DIR)/crt0.cpp
CRT0_O_FILENAME := crt0.o
$(CRT0_O_FILENAME): $(LINKER_SCRIPT_TEMPLATE_FILENAME)
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

firmware_elf_SOURCES += BareMetalSupport/NewlibSyscalls.cpp


# ------------------------------------

# Make all sources recompile if this makefile changes. This will undoubtedly recompile
# too often, but it is the easiest and safest way I could find yet. Note that xxx_OBJECTS
# variables are not documented in the Automake manual, so they could change in the future.
# The way I have tested this is to change the project's version number in configure.ac
# and check that a new firmware binary with the new version number gets built automatically.
$(firmware_elf_OBJECTS): Makefile

LINKER_SCRIPT_FILENAME := $(BARE_METAL_SUPPORT_DIR)/flash.ld

# Note that the linking order specified in xxx_LDADD is important: if library libfoo.a has an undefined symbol,
# and that symbol is in libbar.a, you need to put libfoo.a before libbar.a on the command line.

firmware_elf_LDADD := $(CRT0_O_FILENAME)

firmware_elf_LDFLAGS := $(AM_LDFLAGS)

firmware_elf_LDFLAGS += -Wl,-T$(LINKER_SCRIPT_FILENAME)

firmware_elf_LDFLAGS += -Wl,--gc-sections
firmware_elf_LDFLAGS += -Wl,--warn-common -Wl,--warn-section-align
firmware_elf_LDFLAGS += -Wl,-Map,$(MAP_FILENAME)
firmware_elf_LDFLAGS += -Wl,--cref  # Output a cross reference table, which will land in the map file.

# Make sure that the vector table gets linked in by referencing the file that contains it.
# The entry point is used by GDB. Note that the CPU itself only looks at the vector table,
# so the entry point should match the reset vector.
firmware_elf_LDFLAGS += -Wl,--entry=BareMetalSupport_Reset_Handler

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

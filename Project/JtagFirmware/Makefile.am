
# Copyright (C) 2013 R. Diez
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Affero GNU General Public License version 3
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Affero GNU General Public License version 3 for more details.
#
# You should have received a copy of the Affero GNU General Public License version 3
# along with this program. If not, see http://www.gnu.org/licenses/ .


AUTOMAKE_OPTIONS := foreign
.DELETE_ON_ERROR:

ELF_BASENAME := jtagdue

ELF_FILENAME := jtagdue.elf  # Here substitution $(ELF_BASENAME) does not work (!?).

bin_PROGRAMS := $(ELF_FILENAME)


# ------------------------------------
# Global definitions.

dist_data_DATA :=  # See "dist_data_DATA += ..." statements below.

MAP_FILENAME := $(ELF_BASENAME).map

# ------------------------------------
# Manually compile crt0.cpp to the exact name "crt0.o", so that later the linker finds it.
CRT0_SRC_FILENAME := $(BARE_METAL_SUPPORT_DIR)/crt0.cpp
CRT0_O_FILENAME := crt0.o
$(CRT0_O_FILENAME): $(LINKER_SCRIPT_TEMPLATE_FILENAME)
	echo "Compiling $(CRT0_SRC_FILENAME) to $(CRT0_O_FILENAME)..." && \
        $(CXX) $(AM_CPPFLAGS) $(AM_CXXFLAGS) $(CRT0_SRC_FILENAME) -c -o $(CRT0_O_FILENAME)

# ------------------------------------
# Include paths.

# configure.ac has already set some of the include paths,
# so here we just add all the extra ones we need.

jtagdue_elf_CPPFLAGS := $(AM_CPPFLAGS)
jtagdue_elf_CPPFLAGS += $(ASF_INCLUDES)
jtagdue_elf_CPPFLAGS += -I$(srcdir)/../AsfForJtagFirmware/ConfigFilesForAsf

jtagdue_elf_CPPFLAGS += -I$(BARE_METAL_SUPPORT_DIR)/..  # This is so that including a file like <BareMetalSupport/Miscellaneous.h>
                                                        # does find the files in $(BARE_METAL_SUPPORT_DIR).
                                                        # Not really ideal, but there are no header (*.h) files in $srcdir (hopefully).
jtagdue_elf_CPPFLAGS += $(CMSIS_INCLUDES)


# ------------------------------------
# Build the main .elf file.

jtagdue_elf_SOURCES :=

jtagdue_elf_SOURCES += \
    Main.cpp \
    UsbSupport.cpp \
    Led.cpp \
    UsbConnection.cpp \
    UsbBuffers.cpp \
    BusPirateConnection.cpp \
    BusPirateConsole.cpp \
    BusPirateBinaryMode.cpp \
    BusPirateOpenOcdMode.cpp \
    CommandProcessor.cpp \
    SerialPortConsole.cpp \
    InterruptHandlers.cpp
    # Note that there are other files below.


# See the comments in the Bare Metal Support library's Makefile.am
# for information about why this file is compiled here.
jtagdue_elf_SOURCES += $(BARE_METAL_SUPPORT_DIR)/NewlibSyscalls.cpp

# Make all sources recompile if this makefile changes. This will undoubtedly recompile
# too often, but it is the easiest and safest way I could find yet. Note that xxx_OBJECTS
# variables are not documented in the Automake manual, so they could change in the future.
# The way I have tested this is to change the project's version number in configure.ac
# and check that a new firmware binary with the new version number gets built automatically.
$(jtagdue_elf_OBJECTS): Makefile

LINKER_SCRIPT_FILENAME := $(BARE_METAL_SUPPORT_DIR)/flash.ld

# Note that the linking order is important here: if library libfoo.a has an undefined symbol,
# and that symbol is in libbar.a, you need to put libfoo.a before libbar.a on the command line.

jtagdue_elf_LDADD := ../BareMetalSupport/libbare_metal_support.a \
                    ../AsfForJtagFirmware/libasfforjtagfirmware.a \
                    ../CmsisMakefile/libcmsis.a \
                      $(CRT0_O_FILENAME)

jtagdue_elf_LDFLAGS := $(AM_LDFLAGS)

jtagdue_elf_LDFLAGS += -Wl,-T$(LINKER_SCRIPT_FILENAME)

jtagdue_elf_LDFLAGS += -Wl,--gc-sections
jtagdue_elf_LDFLAGS += -Wl,--warn-common -Wl,--warn-section-align
jtagdue_elf_LDFLAGS += -Wl,-Map,$(MAP_FILENAME)
jtagdue_elf_LDFLAGS += -Wl,--cref  # Output a cross reference table, which will land in the map file.

# Make sure that the vector table gets linked in by referencing the file that contains it.
# The entry point is used by GDB. Note that the CPU itself only looks at the vector table,
# so the entry point should match the reset vector.
jtagdue_elf_LDFLAGS += -Wl,--entry=BareMetalSupport_Reset_Handler

$(ELF_FILENAME): $(LINKER_SCRIPT_FILENAME)


# ------------------------------------
# Create and distribute the .bin file too.

# I haven't found any way to build and install the .bin file to the bin directory,
# but maybe the data dir is the 'right' place for it anyway.
dist_data_DATA += $(ELF_BASENAME).bin

$(ELF_BASENAME).bin: $(ELF_FILENAME)
	echo "Generating binary file \"$(abspath $@)\"..." && \
	$(host)-objcopy -O binary "$<" "$@"


# ------------------------------------
# Distribute the .map file too.

$(MAP_FILENAME): $(ELF_FILENAME)
	echo "This rule is empty, as the step to generate the .elf file also generates the map file." >/dev/null

dist_data_DATA += $(MAP_FILENAME)


# POSSIBLE IMPROVEMENT: Automatically delete these files when recursive target "disassemble" is not specified.
# Otherwise, the contents of these files may be stale.
disassemble-local: $(ELF_BASENAME)-objects-sorted-by-size.map  $(ELF_BASENAME)-objdump-with-disassemble.asm  $(ELF_BASENAME)-sorted-strings.txt $(ELF_BASENAME)-readelf-dump.txt

# Create a list of objects in the ELF file sorted by size, which helps when trying to optimise the bin size.
$(ELF_BASENAME)-objects-sorted-by-size.map: $(ELF_FILENAME)
	echo "Generating object list sorted by size to \"$(abspath $@)\"..." && \
        $(host)-nm --radix=d --demangle --size-sort "$<" >"$@"

$(ELF_BASENAME)-objdump-with-disassemble.asm: $(ELF_FILENAME)
	echo "Dumping with disassemble to \"$(abspath $@)\"..." && \
        $(host)-objdump --demangle --all-headers --disassemble --source --wide  "$<" >"$@"

$(ELF_BASENAME)-readelf-dump.txt: $(ELF_FILENAME)
	echo "Generating readelf dump to \"$(abspath $@)\"..." && \
        $(host)-readelf --file-header --program-headers --section-headers --section-groups --section-details --symbols --version-info --arch-specific --wide  "$<" >"$@"

# Avoid using a pipe in the call to 'sort' below. Otherwise, we would have to enable bash option "set -o pipefail",
# assuming that the shell is Bash.
$(ELF_BASENAME)-sorted-strings.txt: $(ELF_BASENAME).bin
	echo "Extracting strings to \"$(abspath $@)\"..." && \
        $(host)-strings "$<" >"$(ELF_BASENAME)-unsorted-strings.txt" && \
        sort "$(ELF_BASENAME)-unsorted-strings.txt" >"$@"


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

ELF_FILENAME := emptydue.elf

bin_PROGRAMS := $(ELF_FILENAME)


# ------------------------------------
# Global definitions.

dist_data_DATA :=  # See "dist_data_DATA += ..." statements below.

MAP_FILENAME := emptydue.map

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

emptydue_elf_CPPFLAGS := $(AM_CPPFLAGS)

emptydue_elf_CPPFLAGS += -I$(BARE_METAL_SUPPORT_DIR)/..  # This is so that including a file like <BareMetalSupport/Miscellaneous.h>
                                                         # does find the files in $(BARE_METAL_SUPPORT_DIR).
                                                         # Not really ideal, but there are no header (*.h) files in $srcdir (hopefully).
emptydue_elf_CPPFLAGS += $(CMSIS_INCLUDES)
emptydue_elf_CPPFLAGS += $(ASF_INCLUDES)

# ------------------------------------
# Build the main .elf file.

emptydue_elf_SOURCES :=

emptydue_elf_SOURCES += \
    InterruptHandlers.cpp \
    Main.cpp
    # Note that there are other files below.


# See the comments in the Bare Metal Support library's Makefile.am
# for information about why this file is compiled here.
emptydue_elf_SOURCES += $(BARE_METAL_SUPPORT_DIR)/NewlibSyscalls.cpp

# Make all sources recompile if this makefile changes. This will undoubtedly recompile
# too often, but it is the easiest and safest way I could find yet. Note that xxx_OBJECTS
# variables are not documented in the Automake manual, so they could change in the future.
# The way I have tested this is to change the project's version number in configure.ac
# and check that a new firmware binary with the new version number gets built automatically.
$(emptydue_elf_OBJECTS): Makefile

LINKER_SCRIPT_FILENAME := $(BARE_METAL_SUPPORT_DIR)/flash.ld

# Note that the linking order is important here: if library libfoo.a has an undefined symbol,
# and that symbol is in libbar.a, you need to put libfoo.a before libbar.a on the command line.

emptydue_elf_LDADD := ../BareMetalSupport/libbare_metal_support.a \
                      ../AsfForEmptyFirmware/libasfforemptyfirmware.a \
                      ../CmsisMakefile/libcmsis.a \
                      $(CRT0_O_FILENAME)

emptydue_elf_LDFLAGS := $(AM_LDFLAGS)

emptydue_elf_LDFLAGS += -Wl,-T$(LINKER_SCRIPT_FILENAME)

emptydue_elf_LDFLAGS += -Wl,--gc-sections
emptydue_elf_LDFLAGS += -Wl,--warn-common -Wl,--warn-section-align
emptydue_elf_LDFLAGS += -Wl,-Map,$(MAP_FILENAME)
emptydue_elf_LDFLAGS += -Wl,--cref  # Output a cross reference table, which will land in the map file.

# Make sure that the vector table gets linked in by referencing the file that contains it.
# The entry point is used by GDB. Note that the CPU itself only looks at the vector table,
# so the entry point should match the reset vector.
emptydue_elf_LDFLAGS += -Wl,--entry=BareMetalSupport_Reset_Handler

$(ELF_FILENAME): $(LINKER_SCRIPT_FILENAME)


# ------------------------------------
# Create and distribute the .bin file too.

# I haven't found any way to build and install the .bin file to the bin directory,
# but maybe the data dir is the 'right' place for it anyway.
dist_data_DATA += emptydue.bin

%.bin: %.elf
	echo "Generating binary file \"$@\"..." && \
	arm-none-eabi-objcopy -O binary $< $@


# ------------------------------------
# Distribute the .map file too.

%.map: %.elf
	echo "This rule is empty, as the step to generate the .elf file also generates the map file." >/dev/null

dist_data_DATA += $(MAP_FILENAME)


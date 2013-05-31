
# Copyright (C) 2012 R. Diez
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


AUTOMAKE_OPTIONS = foreign

bin_PROGRAMS = jtagdue.elf

lib_LIBRARIES = libcmsis.a \
                libsam.a

# ------------------------------------
# Global definitions.

dist_data_DATA =  # See "dist_data_DATA += ..." statements below.

MAP_FILENAME = jtagdue.map


# ------------------------------------
# Libraries.


# ----- CMSIS comes from Atmel and ARM and has a very liberal license.

# File startup_sam3x.c is no longer compiled with this library. The must had to be modified by the Arduino project anyway,
# and it is problematic because it contains the vector table, which embeds a reference to Reset_Handler,
# and we have a different entry point. The vector table source code has been copied to the BareMetalSupport library (with small changes).
libcmsis_a_SOURCES = \
    $(CMSIS_SRC_TEMPLATE_DIR)/system_sam3x.c  # Only needed for SystemCoreClockUpdate().


# ----- libsam comes from Atmel and has a very liberal license.

LIBSAM_PMC_DIR   := $(ASF_BASEDIR)/sam/drivers/pmc
LIBSAM_PIO_DIR   := $(ASF_BASEDIR)/sam/drivers/pio
LIBSAM_USART_DIR := $(ASF_BASEDIR)/sam/drivers/usart

LIBSAM_USB_DIR                := $(ASF_BASEDIR)/common/services/usb
LIBSAM_USB_UDC_DIR            := $(ASF_BASEDIR)/common/services/usb/udc
LIBSAM_USB_UDI_CDC_DIR        := $(ASF_BASEDIR)/common/services/usb/class/cdc
LIBSAM_USB_UDI_CDC_DEVICE_DIR := $(ASF_BASEDIR)/common/services/usb/class/cdc/device

libsam_a_SOURCES = \
     $(LIBSAM_PMC_DIR)/pmc.c \
     $(LIBSAM_PMC_DIR)/sleep.c \
     $(LIBSAM_PIO_DIR)/pio.c \
     $(ASF_BASEDIR)/sam/drivers/wdt/wdt.c \
     $(ASF_BASEDIR)/sam/drivers/adc/adc.c \
     $(ASF_BASEDIR)/sam/drivers/rstc/rstc.c \
     $(LIBSAM_USB_UDI_CDC_DEVICE_DIR)/udi_cdc.c \
     $(LIBSAM_USB_UDI_CDC_DEVICE_DIR)/udi_cdc_desc.c \
     $(LIBSAM_USB_UDC_DIR)/udc.c \
     $(ASF_BASEDIR)/sam/drivers/uotghs/uotghs_device.c \
     $(ASF_BASEDIR)/common/utils/interrupt/interrupt_sam_nvic.c \
     $(ASF_BASEDIR)/common/services/clock/sam3x/sysclk.c


# ------------------------------------
# Include paths.

# configure.ac has already set some of the include paths,
# so here we just add all the extra ones we need.

AM_CPPFLAGS := $(AM_CPPFLAGS)

# POSSIBLE IMPROVEMENT: We probably do not need these include paths when compiling each component.

AM_CPPFLAGS += -I$(ASF_BASEDIR)/common/services/sleepmgr
AM_CPPFLAGS += -I$(LIBSAM_USART_DIR)
AM_CPPFLAGS += -I$(LIBSAM_USB_UDI_CDC_DIR)
AM_CPPFLAGS += -I$(LIBSAM_USB_UDI_CDC_DEVICE_DIR)
AM_CPPFLAGS += -I$(LIBSAM_USB_UDC_DIR)
AM_CPPFLAGS += -I$(LIBSAM_USB_DIR)

AM_CPPFLAGS += -I$(srcdir)/ConfigFilesForLibsam

AM_CPPFLAGS += -I$(BARE_METAL_SUPPORT_DIR)/..  # This is so that including a file like <BareMetalSupport/Miscellaneous.h>
                                               # does find the files in $(BARE_METAL_SUPPORT_DIR).
                                               # Not really ideal, but there are no header (*.h) files in $srcdir (hopefully).

# ------------------------------------
# Build the main .elf file.

jtagdue_elf_SOURCES :=

jtagdue_elf_SOURCES += \
    Main.cpp \
    UsbSupport.cpp \
    Led.cpp \
    UsbConnection.cpp \
    UsbBuffers.cpp \
    SerialConsole.cpp \
    TextParsingUtils.cpp \
    BusPirateConnection.cpp \
    BusPirateConsole.cpp \
    BusPirateBinaryMode.cpp \
    BusPirateOpenOcdMode.cpp \
    InterruptHandlers.cpp
    # Note that there are other files below.


# See the comments in the Bare Metal Support library's Makefile.am
# for information about why these files are compiled here.

jtagdue_elf_SOURCES += $(BARE_METAL_SUPPORT_DIR)/NewlibSyscalls.cpp
jtagdue_elf_SOURCES += $(BARE_METAL_SUPPORT_DIR)/crt0.cpp


# Note that the linking order is important here: if library libfoo.a has an undefined symbol,
# and that symbol is in libbar.a, you need to put libfoo.a before libbar.a on the command line.

jtagdue_elf_LDADD = ../BareMetalSupport/libbare_metal_support.a \
                    libsam.a \
                    libcmsis.a

jtagdue_elf_LDFLAGS =

jtagdue_elf_LDFLAGS += -Wl,-T$(BARE_METAL_SUPPORT_DIR)/flash.ld

jtagdue_elf_LDFLAGS += -Wl,--gc-sections
jtagdue_elf_LDFLAGS += -Wl,--warn-common -Wl,--warn-section-align
jtagdue_elf_LDFLAGS += -Wl,-Map,$(MAP_FILENAME)
jtagdue_elf_LDFLAGS += -Wl,--cref  # Output a cross reference table, which will land in the map file.


# The --entry switch below may well prevent the entry function from getting discarded, and is used by GDB too.
# However, the CPU itself only looks at the vector table. Therefore, if you change the entry point,
# make sure to update the vector table too.
jtagdue_elf_LDFLAGS += -Wl,--entry=BareMetalSupport_Reset_Handler


# ------------------------------------
# Create and distribute the .bin file too.

# I haven't found any way to build and install the .bin file to the bin directory,
# but maybe the data dir is the 'right' place for it anyway.
dist_data_DATA += jtagdue.bin

%.bin: %.elf
	arm-none-eabi-objcopy -O binary $< $@


# ------------------------------------
# Distribute the .map file too.

%.map: %.elf
	echo "This rule is empty, as the step to generate the .elf file also generates the map file." >/dev/null

dist_data_DATA += $(MAP_FILENAME)


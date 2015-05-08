
AUTOMAKE_OPTIONS := foreign
.DELETE_ON_ERROR:

lib_LIBRARIES := libasfforemptyfirmware.a


# ----- The ASF library comes from Atmel and has a very liberal license.

libasfforemptyfirmware_a_SOURCES := \
     $(ASF_BASEDIR)/sam/drivers/pmc/pmc.c \
     $(ASF_BASEDIR)/sam/drivers/pio/pio.c \
     $(ASF_BASEDIR)/sam/drivers/wdt/wdt.c \
     $(ASF_BASEDIR)/sam/drivers/rstc/rstc.c \
     $(ASF_BASEDIR)/sam/drivers/uart/uart.c \
     $(ASF_BASEDIR)/common/utils/interrupt/interrupt_sam_nvic.c \
     $(ASF_BASEDIR)/common/services/clock/sam3x/sysclk.c

libasfforemptyfirmware_a_CPPFLAGS := $(AM_CPPFLAGS)

# This is the reason why we need a separate ASF library for the EmptyFirmware variant: this config file is different.
libasfforemptyfirmware_a_CPPFLAGS += -I$(srcdir)/ConfigFilesForAsf

libasfforemptyfirmware_a_CPPFLAGS += $(CMSIS_INCLUDES)
libasfforemptyfirmware_a_CPPFLAGS += $(ASF_INCLUDES)

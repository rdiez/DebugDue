
AUTOMAKE_OPTIONS := foreign

lib_LIBRARIES := libasfforjtagfirmware.a


# ----- The ASF library comes from Atmel and has a very liberal license.

LIBSAM_PMC_DIR                := $(ASF_BASEDIR)/sam/drivers/pmc

LIBSAM_USB_DIR                := $(ASF_BASEDIR)/common/services/usb
LIBSAM_USB_UDC_DIR            := $(ASF_BASEDIR)/common/services/usb/udc
LIBSAM_USB_UDI_CDC_DIR        := $(ASF_BASEDIR)/common/services/usb/class/cdc
LIBSAM_USB_UDI_CDC_DEVICE_DIR := $(ASF_BASEDIR)/common/services/usb/class/cdc/device

libasfforjtagfirmware_a_SOURCES := \
     $(LIBSAM_PMC_DIR)/pmc.c \
     $(LIBSAM_PMC_DIR)/sleep.c \
     $(ASF_BASEDIR)/sam/drivers/pio/pio.c \
     $(ASF_BASEDIR)/sam/drivers/wdt/wdt.c \
     $(ASF_BASEDIR)/sam/drivers/adc/adc.c \
     $(ASF_BASEDIR)/sam/drivers/rstc/rstc.c \
     $(ASF_BASEDIR)/sam/drivers/uart/uart.c \
     $(ASF_BASEDIR)/sam/drivers/uotghs/uotghs_device.c \
     $(ASF_BASEDIR)/common/utils/interrupt/interrupt_sam_nvic.c \
     $(ASF_BASEDIR)/common/services/clock/sam3x/sysclk.c \
     $(LIBSAM_USB_UDI_CDC_DEVICE_DIR)/udi_cdc.c \
     $(LIBSAM_USB_UDI_CDC_DEVICE_DIR)/udi_cdc_desc.c \
     $(LIBSAM_USB_UDC_DIR)/udc.c

# This is the reason why we need a separate ASF library for the JtagFirmware variant: this config file is different.
libasfforjtagfirmware_a_CPPFLAGS := -I$(srcdir)/ConfigFilesForAsf

libasfforjtagfirmware_a_CPPFLAGS += $(CMSIS_INCLUDES)
libasfforjtagfirmware_a_CPPFLAGS += $(ASF_INCLUDES)

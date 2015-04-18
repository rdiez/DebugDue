
AUTOMAKE_OPTIONS := foreign
.DELETE_ON_ERROR:

lib_LIBRARIES := libcmsis.a


# ----- CMSIS comes from Atmel and ARM and has a very liberal license.

# File startup_sam3x.c is no longer compiled with this library. The must had to be modified by the Arduino project anyway,
# and it is problematic because it contains the vector table, which embeds a reference to Reset_Handler,
# and we have a different entry point. The vector table source code has been copied to the BareMetalSupport library (with small changes).

libcmsis_a_SOURCES := \
    $(CMSIS_BASE_DIR)/source/templates/system_sam3x.c  # Only needed for SystemCoreClockUpdate().

libcmsis_a_CPPFLAGS := $(CMSIS_INCLUDES)

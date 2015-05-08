
AUTOMAKE_OPTIONS := foreign
.DELETE_ON_ERROR:

lib_LIBRARIES := libbare_metal_support.a


# -----  Bare Metal Support library, which I have written myself.

# Note that files NewlibSyscalls.cpp and crt0.cpp are missing here, see below.

libbare_metal_support_a_SOURCES := \
    AssertionUtils.cpp \
    Miscellaneous.cpp \
    MiscellaneousAsm.S \
    IntegerPrintUtils.cpp \
    IoUtils.cpp \
    SerialPortUtils.cpp \
    SerialPrint.cpp \
    SerialPortAsyncTx.cpp \
    BoardInit.cpp \
    StackCheck.cpp \
    TextParsingUtils.cpp \
    GenericSerialConsole.cpp \
    Uptime.cpp \
    SysTickUtils.cpp \
    BusyWait.cpp \
    MainLoopSleep.cpp


# About file NewlibSyscalls.cpp :
#
# Newlib references syscalls like _sbrk(), but we have not provided them in Libgloss or else,
# see the toolchain makefile for more information.
#
# The problem is that normally a library provides stuff for others to use, but this time
# a library (newlib) wants to use some routines (newlib's syscalls) that other libraries provide.
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
# Therefore, your main project must compile NewlibSyscalls.cpp itself from this directory.

# About file crt0.cpp :
#
# File "crt0.o" gets automatically added to the list of object files to link, but it is not
# not enough for file crt0.cpp to be compiled in this library. First of all, I do not think
# that the linker tries to find crt0.o in any user-supplied libraries. Secondly, by using
# "libbare_metal_support_a_CPPFLAGS" instead of modifying the global AM_CPPFLAGS variable,
# Automake adds a prefix to the resulting crt0.o file, so that it is no longer called
# exactly "crt0.o". This is why the main project makefile compiles crt0.cpp by hand.

libbare_metal_support_a_CPPFLAGS := $(AM_CPPFLAGS)
libbare_metal_support_a_CPPFLAGS += $(CMSIS_INCLUDES)
libbare_metal_support_a_CPPFLAGS += $(ASF_INCLUDES)

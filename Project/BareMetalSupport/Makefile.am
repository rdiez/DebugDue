
AUTOMAKE_OPTIONS = foreign


lib_LIBRARIES = libbare_metal_support.a


# -----  Bare Metal Support library, which I have written myself.

# Note that files NewlibSyscalls.cpp and crt0.cpp are missing here, see below.

libbare_metal_support_a_SOURCES = \
    AssertionUtils.cpp \
    Miscellaneous.cpp \
    MiscellaneousAsm.S \
    IntegerPrintUtils.cpp \
    IoUtils.cpp \
    DebugConsole.cpp \
    BoardInit.cpp \
    StackCheck.cpp \
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
# File crt0.o gets automatically added to the list of object files to link, and
# apparently it is not enough for file crt0.cpp to be in this library.
# Therefore, your main project must compile crt0.cpp itself from this directory.


# ---- Reset configuration ----

# - The Arduino Due provides just a SRST signal (called JTAG_RESET / MASTER-RESET), so the right setting is 'srst_only'.
#
# - I have tested empirically that no JTAG communication can take place while the JTAG_SRST signal is asserted.
#   This is why we need setting 'srst_gates_jtag' and 'connect_deassert_srst'.
#
#   This is unfortunate. It is the reason why the firmware makes a pause on start-up, so that OpenOCD
#   can connect before the firmware goes too far.
#   Some chips, like STM32 and STR9, handle reset better, so they can use settings
#   'srst_nogate' and 'connect_assert_srst' instead.
#
#   However, I do not think that JTAG_SRST just gates the JTAG clock, I think that the whole JTAG logic is reset.
#   That is why we need 'srst_pulls_trst'. Without this option, OpenOCD v0.10.0 and v0.11.0 prints extra errors like:
#     Error: Invalid ACK (7) in DAP response
#   Afterwards, the connection does not work well with OpenOCD v0.10.0. However, OpenOCD v0.11.0
#   seems more robust and the connection still works.
#
# - The SRST signal has a 100 K pull-up resistor, so the right JTAG adapter driver setting is then 'srst_open_drain'.
#   Otherwise, if the debug adapter actively holds SRST high most of the time, the ATmega16U2 AVR microcontroller
#   may no longer be able to trigger a reset when you connect to the 'Programming' USB serial port.
#
# - The default configuration is "reset_config  none  separate". With that configuration, OpenOCD connects
#   to the microcontroller without any errors or warnings. The trouble is, it does not reset the
#   microcontroller's peripherals upon connecting. As a result, if the firmware has run before, the USB peripheral
#   will not work correctly anymore, so the "native USB port" will keep retring to connect,
#   and the heartbeat LED will not blink. That is, the firmware will not operate correctly.
#   Command "cortex_m reset_config sysresetreq" should be able to reset the peripherals,
#   but it does not seem to work, see below for more details.
#
# - With OpenOCD v0.10.0, if you stop the firmware with GDB and then restart debugging, you get these messages:
#     GDB attached to OpenOCD, halting the CPU...
#     undefined debug reason 7 - target needs reset
#   With OpenOCD v0.11.0, the debug reason is '8' instead of '7', but otherwise it is the same.
#   Afterwards, the connection appears to work well.
#
# - With OpenOCD v0.11.0, you get the following errors consistently, whether the firmware was stopped or not:
#     Error: Debug regions are unpowered, an unexpected reset might have happened
#     Error: JTAG-DP STICKY ERROR
#     Error: Could not find MEM-AP to control the core
#   However, debugging seems fine afterwards.

# I have used the SRST hardware signal to reset the Arduino Due for years with OpenOCD
# versions 0.10.0 and 0.11.0, but something has changed in version 0.12.0, and it does not work anymore.
# Instead of further researching the cause, I have decided to try switching to a software-triggered reset.
# From the OpenOCD documentation:
# "(For Cortex-M targets, this is not necessary. The target driver knows how to use trigger an NVIC reset when SRST is not available.)"
# The advantage of this method is that you can debug from the very beginning,
# and you do not need a pause in the Firmware start-up code in order to give OpenOCD enough time to connect
# and be able to debug from the beginning.
set ::DebugDue_UseSrstSignal 0

if $::DebugDue_UseSrstSignal {
  reset_config  srst_only  srst_pulls_trst  srst_gates_jtag  srst_open_drain  connect_deassert_srst
} else {
  reset_config  none
}


# The default setting 'vectreset' does not reset the peripherals. Besides, it is not supported on Cortex-M0, M0+ and M1,
# but that is not a problem, as we have a Cortex-M3.
# The trouble is, Atmel does not document whether SYSRESETREQ in register AIRCR does reset the peripherals or not.
# The ARM documentation states "see you vendor documentation", but I couldn't find anything about this in the Atmel documentation.
# Empirical observation suggests that SYSRESETREQ does not reset the peripherals, or at least the USB peripheral.
# This is why we manually reset the peripherals by writing to the Reset Controller Control Register (RSTC_CR).
cortex_m  reset_config  sysresetreq

set ::REG_RSTC_CR  0x400E1A00

# When using "reset init", OpenOCD already resets the CPU core, but according to the Atmel documentation:
#   "Except for debug purposes, PERRST must always be used in conjunction with PROCRST (PERRST and PROCRST set both at 1 simultaneously)."
# We are actually debugging, so we only need to reset the peripherals. If we reset the CPU too,
# it will start executing instructions, instead of halting after reset.
set ::REG_RSTC_CR_RESET_PERIPHERALS         0xA5000004
set ::REG_RSTC_CR_RESET_CPU_AND_PERIPHERALS 0xA5000005
set ::DebugDue_ResetOnlyPeripherals 1

proc my_reset_init_proc { } {

  # This routine is only used if we are not using the SRST signal,
  # that is, if { ! $::DebugDue_UseSrstSignal } .

  if $::DebugDue_ResetOnlyPeripherals {

    echo "Resetting the microcontroller peripherals..."

    mww $::REG_RSTC_CR $::REG_RSTC_CR_RESET_PERIPHERALS

    echo "Finished resetting the microcontroller peripherals."

  } else {

    echo "Resetting the microcontroller CPU and peripherals..."

    mww $::REG_RSTC_CR $::REG_RSTC_CR_RESET_CPU_AND_PERIPHERALS

    echo "Finished resetting the microcontroller CPU and peripherals."
  }
}

if { ! $::DebugDue_UseSrstSignal } {

  sam3.cpu configure -event reset-init my_reset_init_proc
}


# The JTAG_RESET signal is connected to the NRSTB pin, and the AT91SAM3X8E datasheet states for that pin
# a maximum "Filtered Pulse Width" (Tf) of 1 us and a minimum "Unfiltered Pulse Width" (Tuf) of 100 us.
# The reset signal is also connected to a 10 nF capacitor on the Arduino Due, to the ATmega16U2 microcontroller
# over a 10K resistor, and to some external connector pins.
# Alas, I don't know yet how to translate the values above into a value here.
# The default is 0, and the documentation does not state how long OpenOCD waits, so that it could change
# depending on the PC speed. 1 ms seems a good value.

if $::DebugDue_UseSrstSignal {

  if { $::DebugDue_IsOpenOcdVersion_0_11_0_OrHigher } {
    adapter srst pulse_width 1
  } else {
    adapter_nsrst_assert_width 1
  }
}


# The documented default of 100 ms delay after deasserting SRST is too long.
# With one Arduino Due board running the optimised DebugDue firmware in order to debug another Arduino Due board,
# I have seen that 1 ms is too short, you then get JTAG-DP OVERRUN errors in OpenOCD's log. You need some delay
# so that the CPU can reach the initial short busy-loop delay after the clock is set to 84 MHz,
# where the JTAG connection always succeeds and it can stop the firmware at a very early stage.
# 10 ms is too long for the non-optimised DebugDue firmware, the firmware has time to complete the delay busy-loop
# and goes further. 5 ms seems to work well.
#   adapter_nsrst_assert_width  milliseconds

if $::DebugDue_UseSrstSignal {

  if { $::DebugDue_IsOpenOcdVersion_0_11_0_OrHigher } {
    adapter srst delay 5
  } else {
    adapter_nsrst_delay 5
  }
}


proc arduino_due_reset_and_halt { } {

  echo "Resetting and halting the Arduino Due..."

  if { $::DebugDue_UseSrstSignal } {

    # This function tries to stop the CPU as soon as possible after the reset.
    # OpenOCD has a similar function called "soft_reset_halt". The description is:
    #
    #   "Requesting target halt and executing a soft reset. This is often used when a target
    #    cannot be reset and halted. The target, after reset is released begins to execute code.
    #    OpenOCD attempts to stop the CPU and then sets the program counter back to the
    #    reset vector. Unfortunately the code that was executed may have left the hardware
    #    in an unknown state."
    #
    # The problem with that routine is that, by resetting the program counter, it hides the fact
    # that OpenOCD could not actually stop the CPU at the beginning. Hiding this from the developer
    # is a bad idea in my opinion. That is why I am implementing a similar routine here,
    # but without resetting the program counter, so that the developer always sees that the
    # firmware has run a little before halting.
    #
    reset run

    # This 'sleep' makes OpenOCD somehow print the message "target halted due to debug-request, current mode: Thread"
    # afterwards, and also seems to make GDB hang less when the user types 'stepi' afterwards. Without the 'sleep' below,
    # the 'halt' command sometimes seems to get skipped. Note that this delay adds to the adapter_nsrst_delay above.
    # Note also that this is not sleep() from Jim Tcl, but from OpenOCD, and the duration is in milliseconds.
    sleep 1

    halt

  } else  {

    # We have installed a hook in order to reset properly, see 'my_reset_init_proc'.
    reset init
  }
}


# ---- GDB attach configuration ----

proc my_gdb_attach_proc { } {
  # OpenOCD expects the CPU to halt when GDB connects. Otherwise,
  # you get "Error: Target not halted", and the connection fails.
  echo "GDB has attached to OpenOCD, halting the CPU..."
  halt
}

sam3.cpu configure -event gdb-attach my_gdb_attach_proc

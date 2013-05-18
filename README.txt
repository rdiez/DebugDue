
--- WARNING: This repository is not complete yet ---

JtagDue Project
===============

The main goal of this project is to provide an up-to-date, comfortable bare-metal C++
programming environment for the Arduino Due, with assertions, STL library
and C++ exception support.

A secondary goal is to convert the Arduino Due into an OpenOCD JTAG adapter
by emulating a Bus Pirate from Dangerous Prototypes.
The Arduino Due has a faster USB port and a faster CPU, so it can easily outperform the Bus Pirate.

I made a quick test, and the GDB 'load' command reports a transfer rate of 85 KiB/sec with the JtagDue firmware,
compared to 1 KiB/sec with the Bus Pirate. I must admit I find this huge difference a little suspect,
so I am not sure yet that it is correct. It may have to do with option "buspirate_speed fast"
not working on my Linux system. In any case GDB loads feel generally much faster with JtagDue.

The JTAG features with the JtagDue firmware on the Arduino Due are severely limited though:
- The JTAG interface can only handle 3.3 V signals.
- There is no JTAG clock speed setting, just like the current Bus Pirate / OpenOCD combination (as of April 2013).
  The JTAG clock always runs at maximum speed, which may be too fast for some devices.
  I made some imprecise measurements, and the resulting TCK rate is around 3 MHz.
  This means there is no JTAG adaptive clocking support either.
- The JTAG signal are driven by software and their timings are not clean. For example, TCK does not stay 50 %
  of the time high.
  The lowest-level JTAG bit shifting routine should be written in assembly, help in this area would be appreciated.
- The Arduino Due pull-ups are too weak to be of any use, see comments about setting 'buspirate_pullup' below.

See this page for more information about my experience with the Arduino Due:
  http://www.devtal.de/wiki/Benutzer:Rdiez/ArduinoDue


Installation instructions
-------------------------
 
1) Build the toolchain.
   Change to the 'Toolchain' subdirectory and type "make help" for more information.

2) Download and unpack the Atmel Software Framework into some directory of your choice.

3) Build the JtagDue firmware for the Arduino Due like most Autotools projects:

   a) Make sure the new toolchain's 'bin' subdirectory is in the PATH.
   b) Run autogen.sh in the 'Project' subdirectory.
   c) It is best to build out of the source tree like this:

      mkdir obj
      cd obj
      ../Project/configure --prefix=/some/bin/directory --with-atmel-software-framework=<directory where the ASF is>
      make  --no-builtin-rules  -j $(( $(getconf _NPROCESSORS_ONLN) + 1 ))
      make install

4) Flash the new firmware.

   You will need the Bossac tool in order to download the firmware into the Arduino Due,
   the easiest way to get it is probably to install the Arduino software environment.

   Alternatively, you could use the Arduino Due's JTAG port to download the firmware with GDB,
   but then you need some other JTAG adapter. I have used the Bus Pirate for that purpose.

5) In order to test whether the new firmware is working properly,
   plug the USB cable into the Arduino Due's "native" USB socket (as opposed to the "programming" socket),
   and connect to the virtual serial port with your favorite serial port console emulator.

   For example, this client allows you to conveniently quit the client-side terminal emulator
   (the local 'socat' command) with Ctrl+C:

     socat READLINE,echo=0 /dev/ttyACM0,b115200,raw,echo=0,crnl

   Note that /dev/ttyACM0 may be different on your system, you will have to look for the right
   device name under the /dev directory.

   The firmware does not implement the usual command-line editing comfort features yet, like
   command history and all the standard cursor key movements, but you can use the Readline library
   on the client side instead as follows:

      # Without READLINE, but so that Ctrl+C still quits socat:
      socat -,echo=0,icanon=0 /dev/ttyACM0,b115200,raw,echo=0,crnl

   Due to a protocol limitation, there is no welcome banner. Press the Enter key at least once
   to see the cursor ('>'), or type "help" for a list of available commands.

6) Create a UDEV rule in order to get the same /dev/jtagdue1 name every time.

  When you connect the Arduino Due to your Linux PC, you will get a new virtual serial port like
  /dev/ttyACM0 or /dev/ttyACM1. If you wish to write your own scripts to automate JTAG tasks,
  it is desirable that the assigned device name is always the same.

  The JtagDue firmware uses the standard Arduino Due Vendor and Device IDs, but defines
  serial number "JtagDue1". In order to get a fixed /dev/jtagdue1 device name,
  create a new file called /etc/udev/rules.d/47-JtagDue.rules (as root) with the following content:

    SUBSYSTEM=="tty" ATTRS{idVendor}=="2341" ATTRS{idProduct}=="003e" ATTRS{serial}=="JtagDue1" MODE="0666" SYMLINK+="jtagdue1"

  Theoretically, you can add a GROUP="some_group" option in order to restrict access to a particular user group,
  but I could not make it work on my system.

  The next time you plug the Arduino Due, if it is running the JtagDue firmware, an entry like /dev/ttyACM1
  will still be created, but there will also be a /dev/jtagdue1 link pointing to the right one.
  Restarting udev with "sudo restart udev" should not be necessary for the new rule file to be taken into account.

7) Connect the JTAG pins to the target device.

   You can see the JTAG signal pin numbers on the Arduino Due and their current state (as if they all were inputs)
   with command "JtagPins". This is the output generated:

     TDI   (pin 42): high  |  GND2  (pin 43): low
      -    (pin 44):  -    |  nTRST (pin 45): high
     TMS   (pin 46): high  |  nSRST (pin 47): high
     TDO   (pin 48): high  |  VCC   (pin 49): high
     TCK   (pin 50): high  |  GND1  (pin 51): low

   This is the same pin layout as the 10-pin Altera USB Blaster connector, with some
   Atmel additions from the AVR JTAG header.

   With the command above you can also verify that at least the ground signals (GND1 and GND2)
   are low and the VCC signal is high after connecting the JTAG cable.

8) Connect to the JtagDue with OpenOCD.

  You will need to disconnect the command console beforehand if you have it open.

  Configure OpenOCD as if your JTAG adapter were a Bus Pirate, but bear in mind that:

   - Option 'buspirate_vreg' has no effect, as the Arduino Due has no voltage regulator
     to supply power to other devices.

   - Option 'buspirate_pullup' only affects these 4 JTAG signals, like in the Bus Pirate:
     TDI, TDO, TCK and TMS.
     The reset signals TRST and SRST are not affected (have no pull-up option).

     Note that the built-in pull-ups on the Atmel ATSAM3X8 are too weak (between 50 and 150 KOhm)
     to be of any use. On my dodgy test set-up, and once looked at TCK with the oscilloscope,
     and the rising edges were very long curves, the speed was not enough to run reliably
     at as low as 24 KHz.

   - Option 'buspirate_mode open-drain' uses the Atmel ATSAM3X8's "Multi Drive Control"
     (Open Drain) mode, so that you need to enable the pull-ups (or have an external one)
     in order to guarantee a high level on the line when necessary.


Changelog
=========

- Version 1.0.0, released on 11 may 2013. First public version.


Feedback
========

Please send feedback to rdiezmail-arduino at yahoo.de

The project's official web site is https://github.com/rdiez/JtagDue


License
=======

Copyright (C) R. Diez 2012,  rdiezmail-arduino at yahoo.de

The source code is released under the AGPL 3 license.

Please note that some of the files distributed with this project may have other authors and licenses.

This document is released under the Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0) license.

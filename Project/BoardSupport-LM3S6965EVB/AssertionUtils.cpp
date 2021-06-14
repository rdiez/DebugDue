
// Copyright (C) 2012-2020 R. Diez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the Affero GNU General Public License version 3
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// Affero GNU General Public License version 3 for more details.
//
// You should have received a copy of the Affero GNU General Public License version 3
// along with this program. If not, see http://www.gnu.org/licenses/ .


#include <BareMetalSupport/AssertionUtils.h>  // Include file for this module comes first.


// When the firmware starts, it will probably be too early to print an assertion message to
// the debug console. After the serial port has been initialised and so on,
// the user can set the following function in order to deliver such a message to the user.

static UserPanicMsgFunction s_UserPanicMsgFunction = nullptr;

void SetUserPanicMsgFunction ( const UserPanicMsgFunction functionPointer ) throw()
{
  s_UserPanicMsgFunction = functionPointer;
}


void Panic ( const char * const msg ) throw()
{
  if ( s_UserPanicMsgFunction )
  {
    s_UserPanicMsgFunction( msg );
  }


  // I could not find a way to tell Qemu to make GDB stop here.
  // With a JTAG connection, the BKPT instruction would do the trick.
  // There is an ARM Angel / semihosting command TARGET_SYS_EXIT, with argument ADP_Stopped_BreakPoint,
  // but that makes Qemu quit.

  ForeverHangAfterPanic();
}


void ForeverHangAfterPanic ( void ) throw()
{
  // Forever hang.
  for ( ; ; )
  {
    // If this is a debug build, assume that we are debugging, and freeze here.
    // This helps to see the assertion messages and gives you the option
    // to attach a debugger and see the call stack.
    //
    // On real hardware, instruction WFE breaks debugging over JTAG.
    // When running under Qemu, WFE is ignored, which yields a busy wait.
    // But WFI under Qemu does seem to pause the simulated CPU, so that
    // the host CPU is no longer busy.
    __asm__ volatile ("wfi":::"memory");
  }
}

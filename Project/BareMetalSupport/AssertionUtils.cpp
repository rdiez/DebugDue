
// Copyright (C) 2012 R. Diez
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


#include "AssertionUtils.h"  // Include file for this module comes first.

#include <stddef.h>  // For NULL.

#include <sam3xa.h>  // For __disable_irq().


// When the firmware starts, it will probably be too early to print an assertion message to
// the debug console. After the serial port has been initialised and so on,
// the user can set the following function in order to deliver such a message to the user.

static UserPanicMsgFunction s_UserPanicMsgFunction = NULL;

void SetUserPanicMsgFunction ( const UserPanicMsgFunction functionPointer ) throw()
{
    s_UserPanicMsgFunction = functionPointer;
}


void Panic ( const char * const msg ) throw()
{
    __disable_irq();

    if ( s_UserPanicMsgFunction )
        s_UserPanicMsgFunction( msg );

    // If a JTAG debugger is connected, GDB will stop here.
    // If no debugger is connected, the ARM core may execute the HardFault vector
    // when it sees the following BKPT instruction. Therefore, the HardFault vector
    // should also call ForeverHangAfterPanic(), otherwise you may enter an infinite loop
    // that keeps running the HardFault vector over and over.
    // An alternative to BKPT could be GCC's __builtin_trap().
    asm volatile( "BKPT" );

    ForeverHangAfterPanic();
}


void ForeverHangAfterPanic ( void ) throw()
{
    // Forever hang.
    for ( ; ; )
    {
      // If the watchdog is active, we should probably trigger it here, otherwise
      // we will probably reset and the failed assertion information will be lost.
    }
}

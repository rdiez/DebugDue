
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


#include "Miscellaneous.h"  // Include file for this module comes first.

#include <rstc.h>
#include <wdt.h>


// I find this routine useful during debugging.

void BreakpointPlaceholder ( void )
{
}


// I find this routine useful during debugging.

void ForeverHang ( void )
{
  __disable_irq();

  for ( ; ; )
  {
  }
}


// Check that the assembly alignment directive is working properly for routine BusyWaitAsmLoop.

void AssertBusyWaitAsmLoopAlignment ( void )
{
    #ifndef NDEBUG
      // See the same symbol in assembly for more information.
      const uint8_t INSTRUCTION_LOAD_ALIGNMENT = 16;

      // Depending on the GCC optimisation level (-O0 vs -O1), the function address
      // has sometimes the extra 1 added or not.
      const uintptr_t THUMB_DISPLACEMENT = 1;

      uintptr_t fnAddr = uintptr_t( &BusyWaitAsmLoop );

      if ( 0 != ( fnAddr % 2 ) )
        fnAddr -= THUMB_DISPLACEMENT;

      assert( 0 == ( fnAddr % INSTRUCTION_LOAD_ALIGNMENT ) );
    #endif
}


void ResetBoard ( const bool triggerWatchdogDuringWait )
{
  __disable_irq();

  rstc_start_software_reset( RSTC );

  while ( true )
  {
    // If we do not keep the watchdog happy and it times out during this wait,
    // the reset reason will be wrong when the board starts the next time around.

    if ( triggerWatchdogDuringWait )
      wdt_restart( WDT );
  }
}


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

void BreakpointPlaceholder ( void ) throw()
{
}


// I find this routine useful during debugging.

void ForeverHang ( const bool keepWatchdogHappy ) throw()
{
  __disable_irq();

  for ( ; ; )
  {
    if ( keepWatchdogHappy )
      wdt_restart( WDT );
  }
}


void ResetBoard ( const bool triggerWatchdogDuringWait ) throw()
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


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


#include "TriggerMainLoopIteration.h"  // The include file for this module should come first.

#include <sam3xa.h>


static const bool ENABLE_SLEEP = false;

static volatile bool s_wasMainLoopEventTriggered = false;


void TriggerMainLoopIteration ( void )
{
  if ( ENABLE_SLEEP )
  {
    __SEV();
  }
  else
  {
    s_wasMainLoopEventTriggered = true;
  }
}


void MainLoopSleep ( void )
{
  // There are better ways to sleep and save energy.
  //
  // If we sleep with WFE, we will not be able to wake the CPU up with OpenOCD over JTAG.
  // For more information about this, see OpenOCD ticket #28, titled "Cortex not woken from sleep (ARM ADI v5)".
  //
  // Alternatively, we could use the Sleep Manager here, function sleepmgr_enter_sleep(), see
  // the Atmel Software Framework documentation.

  if ( ENABLE_SLEEP )
  {
    __WFE();
  }
  else
  {
    while ( !s_wasMainLoopEventTriggered )
    {
    }

    s_wasMainLoopEventTriggered = false;
  }
}

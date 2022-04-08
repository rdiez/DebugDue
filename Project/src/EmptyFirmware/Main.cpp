
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


#include <assert.h>

#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/BoardInitUtils.h>
#include <BareMetalSupport/DebugConsoleSerialSync.h>
#include <BareMetalSupport/DebugConsoleEol.h>

#include <Misc/AssertionUtils.h>

#include <ArduinoDueUtils/ArduinoDueUtils.h>

#include <sam3xa.h>  // All interrupt handlers must probably be extern "C", so include their declarations here.

#include <pio.h>


static const bool ENABLE_DEBUG_CONSOLE = true;

#define STACK_SIZE ( 4 * 1024 )
static_assert( 0 == STACK_SIZE % sizeof( uint32_t ), "" );
static uint32_t s_stackSpace[ STACK_SIZE / sizeof( uint32_t ) ] __attribute__ ((section (".placeInStackArea"),used));

static void Configure ( void )
{
  if ( ENABLE_DEBUG_CONSOLE )
  {
    InitDebugConsoleUart( false );

    SerialSyncWriteStr( "--- EmptyDue " PACKAGE_VERSION " ---" EOL );
    SerialSyncWriteStr( "Welcome to the Arduino Due's programming USB serial port." EOL );

    SetUserPanicMsgFunction( &PrintPanicMsg );
  }

  StartUpChecks();

  // Configure the watchdog.
  WDT->WDT_MR = WDT_MR_WDDIS;

  if ( IsDebugBuild() )
  {
    RuntimeStartupChecks();
  }
}


void StartOfUserCode ( void )
{
    Configure();

    if ( ENABLE_DEBUG_CONSOLE )
    {
      PrintFirmwareSegmentSizesSync();
    }

    // ------ Main loop ------

    if ( ENABLE_DEBUG_CONSOLE )
    {
      SerialSyncWriteStr( "Place your application code here." EOL );
    }

    // ------ Terminate ------

    if ( IsDebugBuild() )
    {
      RuntimeTerminationChecks();
    }

    if ( ENABLE_DEBUG_CONSOLE )
    {
      SerialSyncWriteStr( "Wait forever consuming CPU cycles (busy wait)." EOL );
    }

    for (;;)
    {
    }
}


void HardFault_Handler ( void )
{
  // Note that instruction BKPT causes a HardFault when no debugger is currently attached.

  if ( ENABLE_DEBUG_CONSOLE )
  {
    SerialSyncWriteStr( "HardFault" EOL );
  }

  ForeverHangAfterPanic();
}

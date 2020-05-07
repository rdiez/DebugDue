
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

#include <BareMetalSupport/AssertionUtils.h>
#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/BoardInitUtils.h>
#include <BareMetalSupport/SerialPortUtils.h>
#include <BareMetalSupport/DebugConsoleEol.h>

#include <ArduinoDueUtils/ArduinoDueUtils.h>

#include <sam3xa.h>  // All interrupt handlers must probably be extern "C", so include their declarations here.

#include <pio.h>


static const bool ENABLE_DEBUG_CONSOLE = true;


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
}


// These symbols are defined in the linker script file.
extern "C" int _sfixed;
extern "C" int _etext;
extern "C" int _sbss;
extern "C" int _ebss;
extern "C" int _srelocate;
extern "C" int _erelocate;


void StartOfUserCode ( void )
{
    Configure();

    if ( ENABLE_DEBUG_CONSOLE )
    {
      const unsigned codeSize     = unsigned( uintptr_t( &_etext     ) - uintptr_t( &_sfixed    ) );
      const unsigned initDataSize = unsigned( uintptr_t( &_erelocate ) - uintptr_t( &_srelocate ) );
      const unsigned bssDataSize  = unsigned( uintptr_t( &_ebss      ) - uintptr_t( &_sbss      ) );

      SerialSyncWriteStr( "Code size: 0x" );
      SerialSyncWriteUint32Hex( codeSize );
      SerialSyncWriteStr( ", initialised data size: 0x" );
      SerialSyncWriteUint32Hex( initDataSize );
      SerialSyncWriteStr( ", BSS size: 0x" );
      SerialSyncWriteUint32Hex( bssDataSize );
      SerialSyncWriteStr( "." EOL );
    }


    // ------ Main loop ------

    if ( ENABLE_DEBUG_CONSOLE )
    {
      SerialSyncWriteStr( "Entering the main loop, which just waits forever." EOL );
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

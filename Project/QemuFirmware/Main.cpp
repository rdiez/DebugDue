
// Copyright (C) 2020 R. Diez
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
#include <stdint.h>

#include <BareMetalSupport/AssertionUtils.h>
#include <BareMetalSupport/DebugConsoleEol.h>
#include <BareMetalSupport/DebugConsoleSerialSync.h>
#include <BareMetalSupport/BoardInitUtils.h>

#include <BoardSupport-LM3S6965EVB/AngelInterface.h>
#include <BoardSupport-LM3S6965EVB/ExceptionHandlers.h>


static void PrintPanicMsg ( const char * const msg )
{
  SerialSyncWriteStr( EOL );
  SerialSyncWriteStr( "PANIC: " );
  SerialSyncWriteStr( msg );
  SerialSyncWriteStr( EOL );

  // Here it would be a good place to print a stack backtrace,
  // but I have not been able to figure out yet how to do that
  // with the ARM Thumb platform.
}


#define STACK_SIZE ( 4 * 1024 )
static_assert( 0 == STACK_SIZE % sizeof( uint32_t ), "" );
static uint32_t s_stackSpace[ STACK_SIZE / sizeof( uint32_t ) ] __attribute__ ((section (".placeInStackArea"),used));


void StartOfUserCode ( void )
{
  SetUserPanicMsgFunction( &PrintPanicMsg );

  if ( IsDebugBuild() )
  {
    RuntimeStartupChecks();
  }


  // We do not use the CMSIS yet, so we have not got the definitions for the SCB register yet.
  #ifdef __ARM_FEATURE_UNALIGNED
    // assert( 0 == ( SCB->CCR & SCB_CCR_UNALIGN_TRP_Msk ) );
  #else
    // assert( 0 != ( SCB->CCR & SCB_CCR_UNALIGN_TRP_Msk ) );
    #error "We normally do not expect this scenario. Did you forget to specify GCC switch -munaligned-access?"
  #endif


  // The build script and/or Qemu will have printed messages beforehand.
  // An empty line helps delimit where our firmware starts.
  SerialSyncWriteStr( EOL );

  SerialSyncWriteStr( "--- Qemu Firmware " PACKAGE_VERSION " ---" EOL );
  SerialSyncWriteStr( "Welcome to the Qemu Firmare debug console." EOL );

  PrintFirmwareSegmentSizesSync();


  // ------ Main loop ------


  SerialSyncWriteStr( "Place your application code here." EOL );

  if ( IsDebugBuild() )
  {
    RuntimeTerminationChecks();
  }

  if ( true )
  {
    SerialSyncWriteStr( "Wait forever consuming CPU cycles (busy wait)." EOL );
    ForeverHangAfterPanic();
  }
  else
  {
    // We could exit the simulation here with this call:
    Angel_ExitApp();
  }
}


void HardFault_Handler ( void )
{
  // Note that instruction BKPT causes a HardFault when no debugger is currently attached.

  SerialSyncWriteStr( "HardFault" EOL );

  ForeverHangAfterPanic();
}

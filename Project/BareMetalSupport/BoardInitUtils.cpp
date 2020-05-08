
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


#include "BoardInitUtils.h"  // Include file for this module comes first.

#include <assert.h>
#include <stdint.h>

#include <BareMetalSupport/AssertionUtils.h>
#include <BareMetalSupport/LinkScriptSymbols.h>
#include <BareMetalSupport/DebugConsoleSerialSync.h>
#include <BareMetalSupport/SerialPrint.h>


void RunUserCode ( void )
{
  #ifdef __EXCEPTIONS  // If the compiler supports C++ exceptions...

    try
    {
      StartOfUserCode();
    }
    catch ( ... )
    {
      Panic( "C++ exception from user code." );
    }

  #else

    StartOfUserCode();

  #endif
}


void InitDataSegments ( void ) throw()
{
  // Relocate the initialised data from flash to SRAM.

  const uint32_t * relocSrc  = (const uint32_t *)&__etext;
        uint32_t * relocDest = (      uint32_t *)&__data_start__;

  if ( relocSrc == relocDest )
  {
    // This may be the case on a full-blown PC, but we do not expect this on an embedded device.
    assert( false );
  }
  else
  {
    const uint32_t * const relocDestEnd = (const uint32_t *) &__data_end__;

    while ( relocDest < relocDestEnd )
    {
      *relocDest++ = *relocSrc++;
    }
  }

  // Clear the zero segment (BSS).

  const uint32_t * const zeroSegEnd = (const uint32_t *) &__bss_end__;

  for ( uint32_t * zeroSegPtr = (uint32_t *)&__bss_start__;  zeroSegPtr < zeroSegEnd;  ++zeroSegPtr )
  {
    *zeroSegPtr = 0;
  }
}


// This "sync" variant should not be used if the firmware uses the "Serial Port Tx Buffer".

void PrintFirmwareSegmentSizesSync ( void ) throw()
{
  const unsigned codeSize     = unsigned( uintptr_t( &__etext      ) - uintptr_t( &_sfixed        ) );
  const unsigned initDataSize = unsigned( uintptr_t( &__data_end__ ) - uintptr_t( &__data_start__ ) );
  const unsigned bssDataSize  = unsigned( uintptr_t( &__bss_end__  ) - uintptr_t( &__bss_start__  ) );

  SerialSyncWriteStr( "Code size: 0x" );
  SerialSyncWriteUint32Hex( codeSize );
  SerialSyncWriteStr( ", initialised data size: 0x" );
  SerialSyncWriteUint32Hex( initDataSize );
  SerialSyncWriteStr( ", BSS size: 0x" );
  SerialSyncWriteUint32Hex( bssDataSize );
  SerialSyncWriteStr( "." EOL );
}


// This "async" variant uses vsnprintf() and brings in more of the C runtime library (makes the firmware bigger).

void PrintFirmwareSegmentSizesAsync ( void ) throw()
{
  const unsigned codeSize     = unsigned( uintptr_t( &__etext      ) - uintptr_t( &_sfixed        ) );
  const unsigned initDataSize = unsigned( uintptr_t( &__data_end__ ) - uintptr_t( &__data_start__ ) );
  const unsigned bssDataSize  = unsigned( uintptr_t( &__bss_end__  ) - uintptr_t( &__bss_start__  ) );

  SerialPrintf( "Code size: %u, initialised data size: %u, BSS size: %u." EOL,
                codeSize,
                initDataSize,
                bssDataSize );
}

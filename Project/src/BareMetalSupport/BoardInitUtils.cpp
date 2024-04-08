
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
#include <malloc.h>
#include <string.h>
#include <errno.h>

#ifdef _PICOLIBC__
  // Unfortunately, we cannot access this private header here:
  //   #include <atexit.h>
  // So there is no way to get the declaration for _atexit.
#else
  #include <sys/reent.h> // For _GLOBAL_ATEXIT.
#endif

#include <BareMetalSupport/LinkScriptSymbols.h>
#include <BareMetalSupport/DebugConsoleSerialSync.h>
#include <BareMetalSupport/SerialPrint.h>

#include <Misc/AssertionUtils.h>


// Check that the assertion patch for Newlib was applied.
#ifdef _PICOLIBC__
  // I haven't got such a patch for Picolibc yet.
#else
  static_assert( IS_ASSERT_TYPE_HONOURED );
#endif


void RunUserCode ( void ) throw()
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
  const unsigned codeSize     = uintptr_t( &__etext      ) - uintptr_t( &_sfixed        );
  const unsigned initDataSize = uintptr_t( &__data_end__ ) - uintptr_t( &__data_start__ );
  const unsigned bssDataSize  = uintptr_t( &__bss_end__  ) - uintptr_t( &__bss_start__  );
  const unsigned heapSize     = uintptr_t( &__HeapLimit  ) - uintptr_t( &__end__        );

  SerialSyncWriteStr( "Code size: 0x" );
  SerialSyncWriteUint32Hex( codeSize );
  SerialSyncWriteStr( ", initialised data size: 0x" );
  SerialSyncWriteUint32Hex( initDataSize );
  SerialSyncWriteStr( ", BSS size: 0x" );
  SerialSyncWriteUint32Hex( bssDataSize );
  SerialSyncWriteStr( ", malloc heap size: 0x" );
  SerialSyncWriteUint32Hex( heapSize );
  SerialSyncWriteStr( "." EOL );
}


// This "async" variant uses vsnprintf() and brings in more of the C runtime library (makes the firmware bigger).

void PrintFirmwareSegmentSizesAsync ( void ) throw()
{
  const unsigned codeSize     = uintptr_t( &__etext      ) - uintptr_t( &_sfixed        );
  const unsigned initDataSize = uintptr_t( &__data_end__ ) - uintptr_t( &__data_start__ );
  const unsigned bssDataSize  = uintptr_t( &__bss_end__  ) - uintptr_t( &__bss_start__  );
  const unsigned heapSize     = uintptr_t( &__HeapLimit  ) - uintptr_t( &__end__        );

  SerialPrintf( "Code size: %u, initialised data size: %u, BSS size: %u, malloc heap size: %u." EOL,
                codeSize,
                initDataSize,
                bssDataSize,
                heapSize );
}


// This routine may call Panic(), so call it after SetUserPanicMsgFunction(),
// so that you can see the panic message on the console.

#define UNEXPECTED_ENTRIES_IN_THE_ATEXIT_TABLE_ERR_MSG  "Unexpected entries in the atexit table."

void RuntimeStartupChecks ( void ) throw()
{
  const struct mallinfo mi = mallinfo();

  if ( mi.uordblks != 0 )
  {
    // If the patch to disable the C++ exception emergency memory pool in GCC's libsupc++
    // is working properly, there should be no memory allocated at this point.
    Panic( "I do not want anybody to allocate memory with malloc() before starting the application code."  );
  }

  // See the comments next to compilation option -fuse-cxa-atexit for more information.
  // You may of course have a different opinion or different needs with regards to initialisation and atexit,
  // in which case you need to remove this check.

  #ifdef _PICOLIBC__

    // Unfortunately, we cannot access _atexit here, because the corresponding private header file is not accessible.
    //   assert( _atexit == nullptr );

  #elif defined( _GLOBAL_ATEXIT )

    // Newlib up to at least version 4.1.0 defines _GLOBAL_ATEXIT.
    //
    // _GLOBAL_REENT is _global_impure_ptr.
    // _GLOBAL_ATEXIT can be either _global_atexit or _GLOBAL_REENT->_atexit, therefore _global_impure_ptr->_atexit .
    // If not nullptr, then I guess that _GLOBAL_ATEXIT->_ind will not be 0 either.

    if ( _GLOBAL_ATEXIT != nullptr )
    {
      Panic( UNEXPECTED_ENTRIES_IN_THE_ATEXIT_TABLE_ERR_MSG );
    }

  #else

    // Newlib from at least version 4.3.0.20230120 makes __atexit accessible.

    if ( __atexit != nullptr )
    {
      Panic( UNEXPECTED_ENTRIES_IN_THE_ATEXIT_TABLE_ERR_MSG );
    }

  #endif

  // I haven't patched strerror() in Picolibc yet.
  #ifndef _PICOLIBC__

  // Check whether the patch to remove all strerror() strings is working properly.
  // "n/a" means "not available".
  if ( 0 != strcmp( "<n/a>", strerror( ENOENT ) ) )
  {
    Panic( "strerror() does not deliver the expected patched string." );
  }

  #endif  // #ifndef _PICOLIBC__
}


void RuntimeTerminationChecks ( void ) throw()
{
  #ifdef _PICOLIBC__

    // Unfortunately, we cannot access _atexit here, because the corresponding private header file is not accessible.
    //   assert( _atexit == nullptr );

  #elif defined( _GLOBAL_ATEXIT )

    // C++ objects inside static routines can be initialised later, and might land in the atexit() list.
    // Make sure that we did not have any of those by checking the atexit list again at the end.
    // Note that it is best to avoid such static construction and destruction inside C++ routines.
    // You may of course have a different opinion or different needs, in which case you need to remove this check.

    if ( _GLOBAL_ATEXIT != nullptr )
    {
      Panic( UNEXPECTED_ENTRIES_IN_THE_ATEXIT_TABLE_ERR_MSG );
    }

  #else

    if ( __atexit != nullptr )
    {
      Panic( UNEXPECTED_ENTRIES_IN_THE_ATEXIT_TABLE_ERR_MSG );
    }

  #endif

  // You may have to disable this final memory check, as it is not easy to make some libraries
  // like lwIP and even Newlib itself free all memory on termination.
  if ( true )
  {
    // We could free more memory by calling routines like these on termination:
    // - __gnu_cxx::__freeres()
    //   Currently (as of GCC version 10) that only frees the C++ exception emergency memory pool in libsupc++,
    //   but we have patched the toolchain so that it does not get allocated in the first place.
    // - __libc_freeres()
    //   Unfortunately, this routine is only available in the GNU C Library, and not in Newlib or Picolibc.

    // At this point, we should have freed all memory that we have allocated with malloc().
    // You may of course decide to implement termination differently, or not at all,
    // in which case you need to remove this check.
    const struct mallinfo terminateMallinfo = mallinfo();

    if ( terminateMallinfo.uordblks != 0 )
    {
      // If you hit this assert, set a breakpoint at the following locations, and let execution continue:
      // - free()
      // - RunUserCode()
      // This way, you have a chance to see which memory has not been freed before this point,
      // but you only want to keep breaking on free() before the application restarts.
      // If you do not hit free() anymore, you may have a real memory leak. Or maybe some library
      // is not freeing everything upon termination.
      assert( false );
    }
  }
}

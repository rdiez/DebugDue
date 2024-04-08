
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


#include "StackCheck.h"  // Include file for this module comes first.

#include <string.h>  // For memset().

#include <BareMetalSupport/LinkScriptSymbols.h>

#include <Misc/AssertionUtils.h>


static const uint8_t STACK_CANARY_VAL = 0xBA;

void FillStackCanary ( void ) throw()
{
    const uintptr_t SAFETY_MARGIN = 32;
    const uintptr_t stackStartAddr = uintptr_t( & __StackLimit );

    // Possible alternatives:
    //   register unsigned long current_sp __asm__ ("sp");
    //   __asm__ ("mov %0, r13" : "=r" (current_sp));
    const uintptr_t currentStackPtr = uintptr_t( __builtin_frame_address(0) );

    assert( stackStartAddr + SAFETY_MARGIN < currentStackPtr );

    const size_t canarySize = currentStackPtr - stackStartAddr - SAFETY_MARGIN;

    memset( (void *) stackStartAddr, STACK_CANARY_VAL, canarySize );
}


// Returns 'false' if the canary region is not intact any more.
// Note that this check is not watertight, as writing exactly the STACK_CANARY_VAL value
// will not be detected. Therefore, use only for debug purposes!
// NOTE: This routine is always optimised with "__attribute__ ((optimize("O2")))",
//       even in debug builds.

bool CheckStackCanary ( const size_t canarySize ) throw()
{
    const char * p = (const char *) ( & __StackLimit );

    for ( size_t i = 0; i < canarySize; ++i )
    {
        if ( *p != STACK_CANARY_VAL )
        {
            return false;
        }
        ++p;
    }

    return true;
}


size_t GetStackSizeUsageEstimate ( void ) throw()
{
    const uint8_t * const startAddr = (const uint8_t *) & __StackLimit;
    const uint8_t * const endAddr   = (const uint8_t *) & __StackTop;

    for ( const uint8_t * scan = startAddr;
          scan < endAddr;
          ++scan )
    {
        if ( *scan != STACK_CANARY_VAL )
        {
            return size_t( endAddr - scan );
        }
    }

    // It is very rare that the whole stack space has been used up.
    assert( false );
    return size_t( endAddr - startAddr );
}


size_t GetCurrentStackDepth ( void ) throw()
{
    const uintptr_t currentStackPtr = uintptr_t( __builtin_frame_address(0) );
    assert( currentStackPtr < uintptr_t( &__StackTop ) );
    return uintptr_t( &__StackTop ) - currentStackPtr;
}

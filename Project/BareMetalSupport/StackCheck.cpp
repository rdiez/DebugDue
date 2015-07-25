
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
#include <assert.h>

#include "Miscellaneous.h"
#include "AssertionUtils.h"


// These symbols are defined in the linker script file.
extern "C" int _end;  // End of the code and data in SRAM (one byte beyond the end), start of the heap (malloc region).
//extern "C" int _sstack;  // Start of the stack region.
extern "C" int _estack;  // End   of the stack region (one byte beyond the end).


// The stack is at the top of SRAM1, and the heap grows upwards. These routines check that the growing heap
// never reaches the stack area. Otherwise, a Panic() is triggered.
static size_t s_stackSize = 1024;  // The default stack size, can be any size.
static uintptr_t s_heapEndAddr = uintptr_t( &_end );  // At the beginning the heap is 0 bytes long.


static uintptr_t CalculateStackStartAddr ( const size_t stackSize )
{
    return uintptr_t( &_estack ) - stackSize;
}


uintptr_t GetStackStartAddr ( void ) throw()
{
    return CalculateStackStartAddr( s_stackSize );
}


void SetStackSize ( const size_t stackSize ) throw()
{
    if ( s_heapEndAddr > CalculateStackStartAddr( stackSize ) )
        Panic("Heap/Stack collision.");

    s_stackSize = stackSize;
}


uintptr_t GetHeapEndAddr ( void ) throw()
{
    return s_heapEndAddr;
}


void SetHeapEndAddr ( const uintptr_t heapEndAddr ) throw()
{
    if ( s_heapEndAddr > CalculateStackStartAddr( s_stackSize ) )
      Panic("Heap/Stack collision.");

    s_heapEndAddr = heapEndAddr;
}


static const uint8_t STACK_CANARY_VAL = 0xBA;

void FillStackCanary ( void ) throw()
{
    assert( !AreInterruptsEnabled() );

    const uintptr_t SAFETY_MARGIN = 32;
    const uintptr_t stackStartAddr = GetStackStartAddr();

    // Possible alternatives:
    //   register unsigned long current_sp asm ("sp");
    //   asm ("mov %0, r13" : "=r" (current_sp));
    const uintptr_t currentStackPtr = uintptr_t( __builtin_frame_address(0) );

    assert( stackStartAddr + SAFETY_MARGIN < currentStackPtr );

    const size_t canarySize = currentStackPtr - stackStartAddr - SAFETY_MARGIN;

    memset( (void *) GetStackStartAddr(), STACK_CANARY_VAL, canarySize );
}


// Returns 'false' if the canary region is not intact any more.
// Note that this check is not watertight, as writing exactly the STACK_CANARY_VAL value
// will not be detected.

bool CheckStackCanary ( const size_t canarySize ) throw()
{
    const char * p = (const char *) GetStackStartAddr();

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
    const uint8_t * const startAddr = (const uint8_t *) GetStackStartAddr();
    const uint8_t * const endAddr   = (const uint8_t *) &_estack;

    for ( const uint8_t * scan = startAddr;
          scan < endAddr;
          ++scan )
    {
        if ( *scan != STACK_CANARY_VAL )
        {
            return endAddr - scan;
        }
    }

    assert( false );
    return endAddr - startAddr;
}


size_t GetCurrentStackDepth ( void ) throw()
{
    const uintptr_t currentStackPtr = uintptr_t( __builtin_frame_address(0) );
    assert( currentStackPtr < uintptr_t( &_estack ) );
    return uintptr_t( &_estack ) - currentStackPtr;
}

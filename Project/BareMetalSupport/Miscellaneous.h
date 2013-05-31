
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


// Include this header file only once.
#ifndef BMS_MISCELLANEOUS_H_INCLUDED
#define BMS_MISCELLANEOUS_H_INCLUDED

#include <stdint.h>

#include <interrupt.h>

#include <assert.h>

#include "SysTickUtils.h"


#define LF "\n"  // Line Feed, 0x0A.
#define CRLF "\r\n"  // Carriage Return, 0x0D, followed by a Line Feed, 0x0A.

template < typename IntegerType >
IntegerType MinFrom ( const IntegerType a, const IntegerType b )
{
  return a < b ? a : b;
}

template < typename IntegerType >
IntegerType MaxFrom ( const IntegerType a, const IntegerType b )
{
  return a > b ? a : b;
}


// Please do not use this function directly, use the C wrapper BusyWaitLoop().
extern "C" void BusyWaitAsmLoop ( uint32_t iterationCount );

inline void BusyWaitLoop ( const uint32_t iterationCount )
{
    assert( iterationCount > 0 );

    // If you need very large numbers you run the risk of overflowing at some
    // point in time. This assert tries to warn you ahead of time.
    assert( iterationCount < UINT32_MAX / 1000 );

    BusyWaitAsmLoop( iterationCount );
}


inline uint32_t GetBusyWaitLoopIterationCountFromUs ( const uint32_t timeInUs )
{
  assert( timeInUs > 0 );

  const uint32_t BUSY_WAIT_LOOP_ITER_PER_CLK_TICK = 3;

  const uint32_t res = UsToSysTickCount( timeInUs ) / BUSY_WAIT_LOOP_ITER_PER_CLK_TICK;

  assert( res > 0 );

  return res;
}



void AssertBusyWaitAsmLoopAlignment ( void );

void ForeverHang ( void )  __attribute__ ((__noreturn__));


// Please do not use __enable_irq() and __disable_irq() directly, as they do not update
// global variable g_interrupt_enabled. Use the functions in the Atmel Software Framework instead:
//   cpu_irq_enable(), cpu_irq_disable().
//
// In order to save and disable interrupts, and then restore them:
//   const irqflags_t flags = cpu_irq_save();
//     ...
//   cpu_irq_restore( flags );

inline bool AreInterruptsEnabled ( void )
{
  const bool areEnabledAccordingToAtmelSoftwareFramework = cpu_irq_is_enabled();
    
  // Routine cpu_irq_is_enabled() in the Atmel Software Framework uses global variable g_interrupt_enabled,
  // so and I am worried that it could become out of sync with the CPU flag.
  #ifndef NDEBUG
    int primaskValue;

    asm volatile( "mrs %[primaskValue], primask"
                  // output operand list
                  : [primaskValue] "=&r" (primaskValue)
                );

    const bool areEnabledAccordingToPrimask = ( 0 == primaskValue );

    assert( areEnabledAccordingToPrimask == areEnabledAccordingToAtmelSoftwareFramework );
  #endif

  return areEnabledAccordingToAtmelSoftwareFramework;
}

void BreakpointPlaceholder ( void );

void ResetBoard ( bool triggerWatchdogDuringWait )  __attribute__ ((__noreturn__));


#endif  // Include this header file only once.

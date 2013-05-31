
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
#include <assert.h>

#include <interrupt.h>


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

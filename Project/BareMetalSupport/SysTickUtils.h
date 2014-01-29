
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
#ifndef BMS_SYS_TICK_UTILS_H_INCLUDED
#define BMS_SYS_TICK_UTILS_H_INCLUDED

#include <stdint.h>
#include <assert.h>

#include <sam3xa.h>


inline uint32_t GetSysTickValue (void)
{
  return SysTick->VAL & SysTick_LOAD_RELOAD_Msk;
}


inline unsigned long GetSysTickReload (void)
{
  return SysTick->LOAD & SysTick_LOAD_RELOAD_Msk;
}


inline bool IsSysTickClkSrcMclk ( void )
{
  // Some routines in this module assume that the system timer tick source is CLK and not CLK/8.
  return 0 != ( SysTick->CTRL & SysTick_CTRL_CLKSOURCE_Msk );
}


inline uint32_t SysTickCountToMs ( const uint32_t sysTickClockTickCount )
{
  assert( IsSysTickClkSrcMclk() );

  // Otherwise you should adjust the logic below for better accuracy.
  // Beware of possible integer overflows then.
  assert( 0 == ( CPU_CLOCK % 1000 ) );

  return sysTickClockTickCount / ( CPU_CLOCK / 1000 );
}


inline uint32_t SysTickCountToUs ( const uint32_t sysTickClockTickCount )
{
  assert( IsSysTickClkSrcMclk() );

  // Otherwise you should adjust the logic below for better accuracy.
  // Beware of possible integer overflows then.
  assert( 0 == ( CPU_CLOCK % 1000000 ) );

  return sysTickClockTickCount / ( CPU_CLOCK / 1000000 );
}


inline uint32_t UsToCpuClockTickCount ( const uint32_t timeInUs )
{
  // Avoid using variable SystemCoreClock here. It is slower, and this routine
  // is also called very early on start-up, where SystemCoreClock is not yet set.

  // Otherwise you should adjust the logic below for better accuracy.
  // Beware of possible integer overflows then.
  assert( 0 == ( CPU_CLOCK % 1000000 ) );

  const uint32_t clockTicksPerUs = CPU_CLOCK / 1000000;

  return timeInUs * clockTicksPerUs;
}


uint32_t GetElapsedSysTickCount ( uint32_t referenceTimeInThePast );


#endif  // Include this header file only once.

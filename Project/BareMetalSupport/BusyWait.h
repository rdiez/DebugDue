
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
#ifndef BMS_BUSY_WAIT_H_INCLUDED
#define BMS_BUSY_WAIT_H_INCLUDED

#include <stdint.h>
#include <assert.h>

#include "SysTickUtils.h"


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


#endif  // Include this header file only once.

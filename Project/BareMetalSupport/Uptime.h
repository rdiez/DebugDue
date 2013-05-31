
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
#ifndef BMS_UPTIME_H_INCLUDED
#define BMS_UPTIME_H_INCLUDED

#include <stdint.h>
#include <assert.h>

#include "Miscellaneous.h"


// 64 bits are overkill but always safe, no matter what the time resolution is.
extern volatile uint64_t g_updateCounter_internalUseOnly;


inline uint64_t GetUptime ( void )
{
  CAutoDisableInterrupts autoDisableInterrupts;

  return g_updateCounter_internalUseOnly;
}


inline bool HasUptimeElapsedMs ( const uint64_t currentUptime,
                                 const uint64_t referenceTimeInThePast,
                                 const uint16_t millisecondsFromReferenceTime )
{
    assert( millisecondsFromReferenceTime >= 1 );
    assert( referenceTimeInThePast <= currentUptime );
    return currentUptime >= referenceTimeInThePast + millisecondsFromReferenceTime;
}


inline bool HasUptimeElapsed ( const uint64_t currentUptime,
                               const uint64_t referenceTimeInThePast,
                               const uint8_t  secondsFromReferenceTime )
{
    static const uint16_t UPTIME_MS_IN_SEC = 1000;

    assert( ((uint32_t)secondsFromReferenceTime) * UPTIME_MS_IN_SEC <= UINT16_MAX );
    
    return HasUptimeElapsedMs( currentUptime, referenceTimeInThePast, secondsFromReferenceTime * UPTIME_MS_IN_SEC );
}


inline void IncrementUptime ( const uint32_t deltaInMs )
{
    assert( AreInterruptsEnabled() );
    cpu_irq_disable();
    
    g_updateCounter_internalUseOnly += deltaInMs;

    cpu_irq_enable();
}


#endif  // Include this header file only once.

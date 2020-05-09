
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


#include "SysTickUtils.h"  // Include file for this module comes first.


static uint32_t CalculateSysTickDelta ( const uint32_t referenceTimeInThePast, const uint32_t currentTime )
{
  assert( referenceTimeInThePast <= GetSysTickReload() );

  assert( currentTime <= GetSysTickReload() );

  uint32_t elapsedTime;

  if ( currentTime <= referenceTimeInThePast )
  {
    elapsedTime = referenceTimeInThePast - currentTime;
  }
  else
  {
    elapsedTime = GetSysTickReload() + 1 - currentTime + referenceTimeInThePast;
  }

  assert( elapsedTime <= GetSysTickReload() );

  // This assert tries to warn you in advance if you are getting close to the overflow limit.
  assert( elapsedTime < GetSysTickReload() / 10 );

  return elapsedTime;
}


// WARNING: This routine cannot measure intervals >= SYSTEM_TICK_PERIOD_MS.

uint32_t GetElapsedSysTickCount ( const uint32_t referenceTimeInThePast ) throw()
{
  return CalculateSysTickDelta( referenceTimeInThePast, GetSysTickValue() );
}

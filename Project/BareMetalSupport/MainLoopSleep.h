
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

#pragma once

#include <stdint.h>

// Note that CPU load statistics are only available if CPU sleep support is disabled below.
// An alternative implementation using a timer would not have this limitation.
// Also, if you enable the CPU sleep feature, you may not be able to connect with the JTAG debugger.
#define ENABLE_CPU_SLEEP  false


void WakeFromMainLoopSleep ( void ) throw();

void MainLoopSleep ( void );

void CpuLoadStatsTick ( void ) throw();

void UpdateCpuLoadStats ( void );


#define CPU_LOAD_LONG_PERIOD_SLOT_COUNT 60  // Consumes one byte per slot.

// A value of 10 here means that the main loop will run once every 100 ms.
// You need to call UpdateCpuLoadStats() in approximately 100 ms intervals then,
// or the CPU load statistics will be inaccurate.
#define CPU_LOAD_SHORT_PERIOD_SLOT_COUNT 10

void GetCpuLoadStats ( const uint8_t ** lastLongPeriod,
                             uint8_t  * lastLongPeriodIndex,
                       const uint8_t ** lastShortPeriod,
                             uint8_t  * lastShortPeriodIndex );

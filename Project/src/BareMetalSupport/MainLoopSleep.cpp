
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


#include "MainLoopSleep.h"  // The include file for this module should come first.

#include <assert.h>

#include <sam3xa.h>

#include <Misc/AssertionUtils.h>

#include "SerialPrint.h"
#include "Miscellaneous.h"
#include "IntegerPrintUtils.h"


static volatile bool s_wasMainLoopEventTriggered = false;

static volatile uint32_t s_tickCount = 0;  // Access to this variable is protected with an interrupt lock.


// This routine can be called from within interrupt context.

void WakeFromMainLoopSleep ( void ) throw()
{
  if ( ENABLE_CPU_SLEEP )
  {
    __SEV();
  }
  else
  {
    s_wasMainLoopEventTriggered = true;
  }
}


// A value of 0 in these tables means 0% CPU load, and a value of 255 means 100% CPU load.

static uint8_t s_lastLongPeriod[ CPU_LOAD_LONG_PERIOD_SLOT_COUNT ];
static uint8_t s_lastLongPeriodIndex;

static uint8_t s_lastShortPeriod[ CPU_LOAD_SHORT_PERIOD_SLOT_COUNT ];
static uint8_t s_lastShortPeriodIndex;

static uint64_t s_sleepLoopCount;

// The value below was calibrated by hand, see ENABLE_CALIBRATION_MODE.
// Tips for calibrating this value are:
// - Leave any non-essential interfaces (like USB)  unconnected for a short time, as there is less CPU load then.
// - Turn off the main loop wake-ups for time-out purposes.
// - Run a release build (with compiler optimisations turned on).
static const uint64_t CALIBRATED_MAX_LOOP_COUNT = 1049937;


static bool ENABLE_CALIBRATION_MODE = false;
static uint64_t s_maximumSleepLoopCountForCalibration;


static void ShiftSlot ( const uint8_t cpuLoad )
{
  s_lastShortPeriod[ s_lastShortPeriodIndex ] = cpuLoad;

  ++s_lastShortPeriodIndex;

  if ( s_lastShortPeriodIndex == CPU_LOAD_SHORT_PERIOD_SLOT_COUNT )
  {
    s_lastShortPeriodIndex = 0;

    uint32_t average = 0;

    for ( unsigned i = 0; i < CPU_LOAD_SHORT_PERIOD_SLOT_COUNT; ++i )
      average += s_lastShortPeriod[ i ];

    average /= CPU_LOAD_SHORT_PERIOD_SLOT_COUNT;

    assert( average <= 255 );

    s_lastLongPeriod[ s_lastLongPeriodIndex ] = uint8_t( average );

    s_lastLongPeriodIndex = uint8_t( s_lastLongPeriodIndex + 1 ) % CPU_LOAD_LONG_PERIOD_SLOT_COUNT;
  }
}


// This routine should only be called from the main loop,
// as there is no concurrency protection.

void UpdateCpuLoadStats ( void )
{
  static_assert( CPU_LOAD_LONG_PERIOD_SLOT_COUNT < 255, "Index data type too small." );
  static_assert( CPU_LOAD_LONG_PERIOD_SLOT_COUNT < 255, "Index data type too small." );

  if ( ENABLE_CPU_SLEEP )
    return;

  uint32_t capturedTickCount;

  { // Scope for interrupts disabled.
    CAutoDisableInterrupts autoDisableInterrupts;

    capturedTickCount = s_tickCount;
    s_tickCount = 0;
  }

  if ( capturedTickCount == 0 )
    return;

  if ( ENABLE_CALIBRATION_MODE )
  {
    if ( s_sleepLoopCount > s_maximumSleepLoopCountForCalibration )
      s_maximumSleepLoopCountForCalibration = s_sleepLoopCount;
  }


  const uint8_t MAX_CPU_LOAD = 255;

  uint8_t cpuLoad;

  if ( s_sleepLoopCount > CALIBRATED_MAX_LOOP_COUNT )
  {
    // If the manual calibration has been done correctly, this should never happen.
    if ( !ENABLE_CALIBRATION_MODE )
      assert( false );

    cpuLoad = 0;
  }
  else
  {
    const uint64_t newVal = ( CALIBRATED_MAX_LOOP_COUNT - s_sleepLoopCount ) * 255 / CALIBRATED_MAX_LOOP_COUNT;
    assert( newVal <= MAX_CPU_LOAD );

    cpuLoad = uint8_t( newVal );
  }

  s_sleepLoopCount = 0;

  ShiftSlot( cpuLoad );

  capturedTickCount--;

  for ( uint32_t i = 0; i < capturedTickCount; ++i )
  {
    ShiftSlot( MAX_CPU_LOAD );
  }
}


// This routine must be in assembly so that the number of iterations can be calibrated once
// and does not change depending on compiler flags and version.

// Note that there is a similar constant in the include file for assembly modules,
// see that other definition for information about why alignment matters here too.
#define INSTRUCTION_LOAD_ALIGNMENT 16

static void CpuLoadAsmLoop ( volatile bool * wasMainLoopEventTriggered,
                             uint64_t * sleepLoopCount ) __attribute__ (( naked ));

static void CpuLoadAsmLoop ( volatile bool * const /* wasMainLoopEventTriggered */,
                           uint64_t * const /* sleepLoopCount */ )
{
  /* This is the equivalent code in C++:
  for ( ; ; )
  {
    if ( *wasMainLoopEventTriggered )
    {
      break;
    }

    ++*sleepLoopCount;
  }
  */

  // Possible improvements:
  // 1) Do not use a 'naked' function.
  // 2) Do not access the stack arguments by address, but use their names
  //    from the function prototype.

  __asm__ volatile
  (
     "ldrb    r3, [r0, #0]"  "\n"
     "push    {r4, r5, r6}"  "\n"
     "cbnz    r3, AsmLoopExitLabel"  "\n"
     "movs    r4, #1"  "\n"
     "movs    r5, #0"  "\n"
     "ldrd    r2, r3, [r1]"  "\n"

     // The whole loop fits exactly in the 16-byte alignment and runs much faster.
     // Speed is actually not so important here, but the runtime should not depend
     // on some compilation randomness, therefore we must align here.
     //
     // I have not managed yet to use a named constant like INSTRUCTION_LOAD_ALIGNMENT
     // instead of the hard-coded 16 below, the %[inst_align] syntax does not work.

     ".balignw 16, 0xBF00"  "\n"  // A thumb 'nop' instruction has opcode 0xBF00.
   "AsmLoopLoopLabel:"  "\n"

      "ldrb    r6, [r0, #0]"  "\n"
      "adds    r2, r2, r4"  "\n"
      "adc.w   r3, r3, r5"  "\n"
      "cmp r6, #0"  "\n"
      "beq.n   AsmLoopLoopLabel"  "\n"
      "strd    r2, r3, [r1]"  "\n"

   "AsmLoopExitLabel:"  "\n"

        "pop {r4, r5, r6}"  "\n"
        "bx lr"  "\n"

     // Output operand list
     :

     // Input operand list
     : [inst_align] "I" ( INSTRUCTION_LOAD_ALIGNMENT )

     // Clobber list
     :
  );
}


// This routine should only be called from the main loop.

void MainLoopSleep ( void )
{
  // There are probably better ways to sleep and save energy.
  //
  // If we sleep with WFE, we will not be able to wake the CPU up with OpenOCD over JTAG.
  // For more information about this, see OpenOCD ticket #28, titled "Cortex not woken from sleep (ARM ADI v5)".
  //
  // Alternatively, we could use the sleep functions that are usually present in
  // the CPU manufacturer's library. For example, for Atmel chips, see the "Sleep Manager",
  // function sleepmgr_enter_sleep(), in the Atmel Software Framework documentation.

  if ( ENABLE_CPU_SLEEP )
  {
    __WFE();
  }
  else
  {
    CpuLoadAsmLoop( &s_wasMainLoopEventTriggered, &s_sleepLoopCount );

    s_wasMainLoopEventTriggered = false;
  }
}


// This routine can be called from within interrupt context.

void CpuLoadStatsTick ( void ) throw()
{
  if ( ENABLE_CPU_SLEEP )
  {
    assert( false );
  }
  else
  {
    CAutoDisableInterrupts autoDisableInterrupts;

    s_tickCount = s_tickCount + 1;
  }
}


// The caller must read the CPU load data starting from the given index and
// incrementing it modulo CPU_LOAD_LONG_PERIOD_SLOT_COUNT or CPU_LOAD_SHORT_PERIOD_SLOT_COUNT.

void GetCpuLoadStats ( const uint8_t ** const lastLongPeriod,
                       uint8_t  * const lastLongPeriodIndex,
                       const uint8_t ** const lastShortPeriod,
                       uint8_t  * const lastShortPeriodIndex )
{
  if ( ENABLE_CPU_SLEEP )
  {
    assert( false );
  }
  else
  {
    *lastLongPeriod      = s_lastLongPeriod;
    *lastLongPeriodIndex = s_lastLongPeriodIndex;

    *lastShortPeriod      = s_lastShortPeriod;
    *lastShortPeriodIndex = s_lastShortPeriodIndex;

    if ( ENABLE_CALIBRATION_MODE )
    {
      char buffer[ CONVERT_TO_DEC_BUF_SIZE ];
      SerialPrintf( "Max loop count found: %s\n", convert_unsigned_to_dec_th( s_maximumSleepLoopCountForCalibration, buffer, ',' ) );
    }
  }
}

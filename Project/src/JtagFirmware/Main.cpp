
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


#include <stdexcept>
#include <assert.h>
#include <inttypes.h>

#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/BusyWait.h>
#include <BareMetalSupport/BoardInitUtils.h>
#include <BareMetalSupport/StackCheck.h>
#include <BareMetalSupport/Uptime.h>
#include <BareMetalSupport/IoUtils.h>
#include <BareMetalSupport/DebugConsoleSerialSync.h>
#include <BareMetalSupport/SerialPortAsyncTx.h>
#include <BareMetalSupport/SerialPrint.h>
#include <BareMetalSupport/MainLoopSleep.h>

#include <ArduinoDueUtils/ArduinoDueUtils.h>

#include "Globals.h"
#include "UsbConnection.h"
#include "UsbSupport.h"
#include "Led.h"
#include "SerialPortConsole.h"
#include "BusPirateOpenOcdMode.h"

#include <sam3xa.h>  // All interrupt handlers must probably be extern "C", so include their declarations here.
#include <pio.h>
#include <pmc.h>
#include <wdt.h>


const uint32_t WATCHDOG_PERIOD_MS = 1000;

#ifndef NDEBUG
  static const size_t MIN_UNUSED_STACK_SIZE = size_t( MaxFrom( MaxFrom( ASSERT_MSG_BUFSIZE, MAX_SERIAL_PRINT_LEN ), MAX_USB_PRINT_LEN ) + 200 );
#endif


static uint32_t GetWdtPeriod ( const uint32_t dwMs )
{
    if ( (dwMs < 4) || (dwMs > 16000) )
    {
        return 0 ;
    }
    return ((dwMs << 8) / 1000) ;
}


#define STACK_SIZE ( 4 * 1024 )
static_assert( 0 == STACK_SIZE % sizeof( uint32_t ), "" );
static uint32_t s_stackSpace[ STACK_SIZE / sizeof( uint32_t ) ] __attribute__ ((section (".placeInStackArea"),used));

static void Configure ( void )
{
  InitDebugConsoleUart( true );

  InitSerialPortAsyncTx( EOL );

  // Print the following message only the on serial port, and not on the USB port.
  //
  // The first EOLs help delimit any old content on the console
  // from the new firmware restart.
  SerialPrintf( EOL
                EOL
                "--- DebugDue %s ---" EOL
                "Welcome to the Arduino Due's programming USB serial port." EOL,
                PACKAGE_VERSION );

  SetUserPanicMsgFunction( &PrintPanicMsg );

  if ( IsDebugBuild() )
  {
    RuntimeStartupChecks();
  }


  // ------- Configure the LED -------

  ConfigureLedPort();


  // ------- Configure the Systick -------

  assert( SystemCoreClock == CPU_CLOCK );
  assert( 0 == ( CPU_CLOCK % 1000 ) );  // Otherwise you should adjust the logic below for better accuracy.
                                        // Beware of possible integer overflows then.
  if ( 0 != SysTick_Config( CPU_CLOCK / 1000 * SYSTEM_TICK_PERIOD_MS ) )
    Panic( "SysTick error." );


  // ------- Configure the USB interface -------

  // Configure the I/O pins of the 'native' USB interface.

  VERIFY( pio_configure( PIOB,
                         PIO_PERIPH_A,
                         PIO_PB11A_UOTGID | PIO_PB10A_UOTGVBOF,
                         PIO_DEFAULT ) );
  InitUsb();


  // ------- Setup the stack size and canary check -------

  #ifndef NDEBUG
    assert( AreInterruptsEnabled() );
    cpu_irq_disable();
    FillStackCanary();
    cpu_irq_enable();
  #endif


  StartUpChecks();

  assert( IsBusyWaitAsmLoopAligned() );


  // ------- Adjust and check some SCB CCR flags -------

  // We could clear here bit STKALIGN in the SCB CCR register in order to save 4 bytes per interrupt stack frame.

  SCB->CCR |= SCB_CCR_DIV_0_TRP_Msk;  // Trap on division by 0.


  // ------- Configure the JTAG pins -------

  if ( USE_PARALLEL_ACCESS )
  {
    // These registers default to 0.
    PIOA->PIO_OWER = 0xFFFFFFFF;
    PIOB->PIO_OWER = 0xFFFFFFFF;
    PIOC->PIO_OWER = 0xFFFFFFFF;
    PIOD->PIO_OWER = 0xFFFFFFFF;

    if ( false )
    {
      SerialPrintf( "A PIO_OWSR: 0x%08" PRIX32 EOL, PIOA->PIO_OWSR );
      SerialPrintf( "B PIO_OWSR: 0x%08" PRIX32 EOL, PIOB->PIO_OWSR );
      SerialPrintf( "C PIO_OWSR: 0x%08" PRIX32 EOL, PIOC->PIO_OWSR );
      SerialPrintf( "D PIO_OWSR: 0x%08" PRIX32 EOL, PIOD->PIO_OWSR );
    }
  }

  // We need to provide the clock to all those PIOs where we will be reading pin values from.
  // We probably do not need all of PIOs below, we could save some power by leaving
  // unnecessary clocks disabled.

  //  pmc_enable_all_periph_clk();  // This does not work, it hangs forever. It probably tries to enable too many peripherals.

  VERIFY( 0 == pmc_enable_periph_clk( ID_PIOA ) );
  VERIFY( 0 == pmc_enable_periph_clk( ID_PIOB ) );
  VERIFY( 0 == pmc_enable_periph_clk( ID_PIOC ) );
  VERIFY( 0 == pmc_enable_periph_clk( ID_PIOD ) );

  if ( false )
  {
    SerialPrintf( "A PIO_PSR: 0x%08" PRIX32 EOL, PIOA->PIO_PSR );
    SerialPrintf( "B PIO_PSR: 0x%08" PRIX32 EOL, PIOB->PIO_PSR );
    SerialPrintf( "C PIO_PSR: 0x%08" PRIX32 EOL, PIOC->PIO_PSR );
    SerialPrintf( "D PIO_PSR: 0x%08" PRIX32 EOL, PIOD->PIO_PSR );
  }

  InitJtagPins();


  // ------- Configure the watchdog -------

  if ( ENABLE_WDT )
  {
    // This time may be too short, turn PRINT_LONGEST_ITERATION_TIME on below to get an idea about timing.
    const uint32_t wdp_ms = GetWdtPeriod( WATCHDOG_PERIOD_MS );
    assert( wdp_ms != 0 );

    const uint32_t wdp_mode = wdp_ms           |  // Field WDV.
                              ( wdp_ms << 16 ) |  // Field WDD.
                              WDT_MR_WDDBGHLT  |  // Otherwise, debugging over JTAG is impossible.
                                                  // Alternatively, you could automate setting this flag in your GDB connection script.
                              WDT_MR_WDRSTEN;
    WDT->WDT_MR = wdp_mode;
  }
  else
  {
    // The watchdog is enabled on start-up, so we need to disable it
    // if we won't be using it.
    WDT->WDT_MR = WDT_MR_WDDIS;
  }
}


static void PeriodicAction ( void )
{
  ToggleLed();
}


void StartOfUserCode ( void )
{
    Configure();

    if ( true )
    {
      PrintFirmwareSegmentSizesAsync();
    }


    // ------ Main loop ------

    if ( IsDebugBuild() )
    {
      SerialPrintf( "Stack entering main loop: current depth: %zu, estimated usage %zu, max room %u bytes." EOL,
                    GetCurrentStackDepth(),
                    GetStackSizeUsageEstimate(),
                    unsigned( STACK_SIZE ) );

    }

    SerialPrintStr( "Entering the main loop." EOL );

    InitSerialPortConsole();  // Call this after the last message printed to the serial port.

    uint64_t longestIterationTime = 0;

    uint64_t lastReferenceTimeForPeriodicAction = 0;

    for (;;)
    {
      if ( ENABLE_WDT )
        wdt_restart( WDT );

      const uint64_t currentTime = GetUptime();

      ServiceUsbConnection( currentTime );

      ServiceSerialPortConsole( currentTime );

      if ( HasUptimeElapsedMs( currentTime, lastReferenceTimeForPeriodicAction, 500 ) )
      {
        lastReferenceTimeForPeriodicAction = currentTime;
        PeriodicAction();

        assert( CheckStackCanary( MIN_UNUSED_STACK_SIZE ) );
      }

      // If somebody forgets to re-enable the interrupts after disabling them, detect it as soon as possible.
      assert( AreInterruptsEnabled() );

      UpdateCpuLoadStats();


      const bool PRINT_LONGEST_ITERATION_TIME = false;

      const uint64_t currentIterationTime = GetUptime() - currentTime;

      if ( ENABLE_WDT )
        assert( currentIterationTime < WATCHDOG_PERIOD_MS / 3 );  // Otherwise you are getting too close to the limit.

      const uint64_t prevLongestInterationTime = longestIterationTime;

      longestIterationTime = MaxFrom( longestIterationTime, currentIterationTime );

      // Early warning if the value gets too high, although I do not think that this will ever overflow.
      assert( longestIterationTime < 10000 );

      if ( PRINT_LONGEST_ITERATION_TIME &&
           longestIterationTime != prevLongestInterationTime )
      {
        // In case the C runtime does not support printing 64-bit integers, reduce it to 32 bits.
        SerialPrintf( "%" PRIu32 EOL, uint32_t( longestIterationTime ) );
      }

      MainLoopSleep();
    }

    // The main loop does not really terminate at the moment, so this code is never reached.
    if ( IsDebugBuild() )
    {
      RuntimeTerminationChecks();
    }
}


void HardFault_Handler ( void )
{
  // Note that instruction BKPT causes a HardFault when no debugger is currently attached.

  SerialSyncWriteStr( "HardFault" EOL );

  ForeverHangAfterPanic();
}


static uint32_t s_mainLoopWakeUpCounterTimeouts = 0;
static uint32_t s_mainLoopWakeUpCounterCpuLoad  = 0;

void SysTick_Handler ( void )
{
  if ( false )
    SerialPrintStr( "." );

  IncrementUptime( SYSTEM_TICK_PERIOD_MS );


  // Wake the main loop up at regular intervals, in case the user code wants to trigger actions based on time-outs.

  if ( true ) // Sometimes it is desirable for test or CPU load calibration purposes to disable this wake-up logic.
  {
    const uint32_t MAINLOOP_WAKE_UP_TIMEOUTS_MS = 250;
    const uint32_t MAINLOOP_WAKE_UP_TIMEOUTS_TICK_COUNT = MAINLOOP_WAKE_UP_TIMEOUTS_MS / SYSTEM_TICK_PERIOD_MS;
    STATIC_ASSERT( 0 == ( MAINLOOP_WAKE_UP_TIMEOUTS_MS % SYSTEM_TICK_PERIOD_MS ), "The wake-up frequency will jitter." );

    assert( s_mainLoopWakeUpCounterTimeouts < MAINLOOP_WAKE_UP_TIMEOUTS_TICK_COUNT );
    ++s_mainLoopWakeUpCounterTimeouts;

    if ( s_mainLoopWakeUpCounterTimeouts == MAINLOOP_WAKE_UP_TIMEOUTS_TICK_COUNT )
    {
      s_mainLoopWakeUpCounterTimeouts = 0;
      WakeFromMainLoopSleep();
    }
  }


  // Wake the main loop up at regular intervals for the purposes of CPU load calculations.

  if ( !ENABLE_CPU_SLEEP )
  {
    const uint32_t MAINLOOP_WAKE_UP_CPU_LOAD_MS = 1000 / CPU_LOAD_SHORT_PERIOD_SLOT_COUNT;
    STATIC_ASSERT( 0 == ( 1000 % CPU_LOAD_SHORT_PERIOD_SLOT_COUNT ), "Cannot accurately calculate CPU load." );
    const uint32_t MAINLOOP_WAKE_UP_CPU_LOAD_TICK_COUNT = MAINLOOP_WAKE_UP_CPU_LOAD_MS / SYSTEM_TICK_PERIOD_MS;
    STATIC_ASSERT( 0 == ( MAINLOOP_WAKE_UP_CPU_LOAD_MS % SYSTEM_TICK_PERIOD_MS ), "The CPU load statistics will jitter." );

    assert( s_mainLoopWakeUpCounterCpuLoad < MAINLOOP_WAKE_UP_CPU_LOAD_TICK_COUNT );
    ++s_mainLoopWakeUpCounterCpuLoad;

    if ( s_mainLoopWakeUpCounterCpuLoad == MAINLOOP_WAKE_UP_CPU_LOAD_TICK_COUNT )
    {
      s_mainLoopWakeUpCounterCpuLoad = 0;
      CpuLoadStatsTick();
      WakeFromMainLoopSleep();
    }
  }
}

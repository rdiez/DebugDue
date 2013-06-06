
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

#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/BusyWait.h>
#include <BareMetalSupport/BoardInit.h>
#include <BareMetalSupport/StackCheck.h>
#include <BareMetalSupport/Uptime.h>
#include <BareMetalSupport/IoUtils.h>
#include <BareMetalSupport/DebugConsole.h>
#include <BareMetalSupport/MainLoopSleep.h>

#include "Globals.h"
#include "UsbConnection.h"
#include "UsbSupport.h"
#include "Led.h"
#include "BusPirateOpenOcdMode.h"

#include <sam3xa.h>  // All interrupt handlers must probably be extern "C", so include their declarations here.
#include <pio.h>
#include <pmc.h>
#include <wdt.h>
#include <usart.h>


const uint32_t WATCHDOG_PERIOD_MS = 1000;

#ifndef NDEBUG
  static const size_t MIN_UNUSED_STACK_SIZE = MaxFrom( MaxFrom( ASSERT_MSG_BUFSIZE, MAX_DBGCON_PRINT_LEN ), MAX_USB_PRINT_LEN ) + 200;
#endif


static uint32_t GetWdtPeriod ( const uint32_t dwMs )
{
    if ( (dwMs < 4) || (dwMs > 16000) )
    {
        return 0 ;
    }
    return ((dwMs << 8) / 1000) ;
}


static void PrintPanicMsg ( const char * const msg )
{
  // This routine is called with interrupts disabled and should rely
  // on as little other code as possible.
  DbgconSyncWriteStr( EOL );
  DbgconSyncWriteStr( "PANIC: " );
  DbgconSyncWriteStr( msg );
  DbgconSyncWriteStr( EOL );

  // Here it would be a good place to print a stack backtrace,
  // but I have not been able to figure out yet how to do that
  // with the ARM Thumb platform.
}


static void Configure ( void )
{
  // ------- Configure the UART connected to the AVR controller -------

  VERIFY( pio_configure( PIOA, PIO_PERIPH_A,
                         PIO_PA8A_URXD | PIO_PA9A_UTXD, PIO_DEFAULT ) );

  // Enable the pull-up resistor for RX0.
  pio_pull_up( PIOA, PIO_PA8A_URXD, ENABLE ) ;

  InitDebugConsole();
  // Print this msg only on serial port, and not on USB port:
  DbgconPrint( "--- JtagDue %s ---" EOL, PACKAGE_VERSION );
  DbgconPrintStr( "Welcome to the Arduino Due's programming USB serial port." EOL );

  SetUserPanicMsgFunction( &PrintPanicMsg );


  // ------- Configure the LED -------

  ConfigureLedPort();


  // ------- Configure the Systick -------

  if ( 0 != SysTick_Config( SystemCoreClock * SYSTEM_TICK_PERIOD_MS / 1000 ) )
    Panic( "SysTick error." );


  // ------- Configure the USB interface -------

  // Configure the I/O pins of the 'native' USB interface.

  VERIFY( pio_configure( PIOB,
                         PIO_PERIPH_A,
                         PIO_PB11A_UOTGID | PIO_PB10A_UOTGVBOF,
                         PIO_DEFAULT ) );
  InitUsb();


  // ------- Setup the stack size and canary check -------

  SetStackSize( STACK_SIZE );

  #ifndef NDEBUG
    assert( AreInterruptsEnabled() );
    cpu_irq_disable();
    FillStackCanary();
    cpu_irq_enable();
  #endif


  // ------- Perform some assorted checks -------

  assert( IsBusyWaitAsmLoopAligned() );

  assert( IsJtagTdoPullUpActive() );

  // Check that the brown-out detector is active.
  #ifndef NDEBUG
    const uint32_t supcMr = SUPC->SUPC_MR;
    assert( ( supcMr & SUPC_MR_BODDIS   ) == SUPC_MR_BODDIS_ENABLE   );
    assert( ( supcMr & SUPC_MR_BODRSTEN ) == SUPC_MR_BODRSTEN_ENABLE );
  #endif


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
      DbgconPrint( "A PIO_OWSR: 0x%08X" EOL, unsigned( PIOA->PIO_OWSR ) );
      DbgconPrint( "B PIO_OWSR: 0x%08X" EOL, unsigned( PIOB->PIO_OWSR ) );
      DbgconPrint( "C PIO_OWSR: 0x%08X" EOL, unsigned( PIOC->PIO_OWSR ) );
      DbgconPrint( "D PIO_OWSR: 0x%08X" EOL, unsigned( PIOD->PIO_OWSR ) );
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
    DbgconPrint( "A PIO_PSR: 0x%08X" EOL, unsigned( PIOA->PIO_PSR ) );
    DbgconPrint( "B PIO_PSR: 0x%08X" EOL, unsigned( PIOB->PIO_PSR ) );
    DbgconPrint( "C PIO_PSR: 0x%08X" EOL, unsigned( PIOC->PIO_PSR ) );
    DbgconPrint( "D PIO_PSR: 0x%08X" EOL, unsigned( PIOD->PIO_PSR ) );
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
                              WDT_MR_WDRSTEN;
    WDT->WDT_MR = wdp_mode;
  }
  else
  {
    WDT->WDT_MR = WDT_MR_WDDIS;
  }
}


static void PeriodicAction ( void )
{
  ToggleLed();
}


// These symbols are defined in the linker script file.
extern uint32_t _sfixed;
extern uint32_t _etext;
extern uint32_t _sbss;
extern uint32_t _ebss;
extern uint32_t _srelocate;
extern uint32_t _erelocate;


void StartOfUserCode ( void )
{
    Configure();

    if ( true )
    {
      const unsigned codeSize     = unsigned( uintptr_t( &_etext     ) - uintptr_t( &_sfixed    ) );
      const unsigned initDataSize = unsigned( uintptr_t( &_erelocate ) - uintptr_t( &_srelocate ) );
      const unsigned bssDataSize  = unsigned( uintptr_t( &_ebss      ) - uintptr_t( &_sbss      ) );

      DbgconPrint( "Code size: %u, initialised data size: %u, BSS size: %u." EOL,
                   codeSize,
                   initDataSize,
                   bssDataSize );
    }


    // ------ Main loop ------

    DbgconPrintStr( "Entering the main loop." EOL );

    uint64_t longestIterationTime = 0;

    uint64_t lastReferenceTimeForPeriodicAction = 0;

    for (;;)
    {
      if ( ENABLE_WDT )
        wdt_restart( WDT );

      const uint64_t currentTime = GetUptime();

      ServiceUsbConnection( currentTime );

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

      if ( PRINT_LONGEST_ITERATION_TIME &&
           longestIterationTime != prevLongestInterationTime )
      {
          DbgconPrint( "%u" EOL, unsigned( longestIterationTime ) );
      }

      MainLoopSleep();
    }
}


void HardFault_Handler ( void )
{
  // Note that instruction BKPT causes a HardFault when no debugger is currently attached.

  DbgconSyncWriteStr( "HardFault" EOL );

  ForeverHangAfterPanic();
}


static uint32_t s_mainLoopWakeUpCounterTimeouts = 0;
static uint32_t s_mainLoopWakeUpCounterCpuLoad  = 0;

void SysTick_Handler ( void )
{
  if ( false )
    DbgconSyncWriteStr( "." );


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
    const uint32_t MAINLOOP_WAKE_UP_CPU_LOAD_MS = 1000 / CPU_LOAD_SECOND_SLOT_COUNT;
    STATIC_ASSERT( 0 == ( 1000 % CPU_LOAD_SECOND_SLOT_COUNT ), "Cannot accurately calculate CPU load." );
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

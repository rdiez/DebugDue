
#include "ArduinoDueUtils.h"  // The include file for this module should come first.

#include <BareMetalSupport/IoUtils.h>
#include <BareMetalSupport/SerialPortUtils.h>
#include <BareMetalSupport/DebugConsoleEol.h>
#include <BareMetalSupport/LinkScriptSymbols.h>


// According to the documentation:
//  "TDO pin is set in input mode when the Cortex-M3 Core is not in debug mode. Thus the internal
//   pull-up corresponding to this PIO line must be enabled to avoid current consumption due to floating input."
// Pin TDO/TRACESWO = PB30 = Pin number 30 (in the 144-ball LFBGA pinout).
// Upon reset, the pull-up should be active, and this routine should be called in order to assert
// that it returns true.

bool IsJtagTdoPullUpActive ( void ) throw()
{
  Pio * const pioPtr = PIOB;

  const uint8_t PIN_NUMBER = 30;

  // This pin is used for JTAG purposes and must not be controlled by the PIO Controller.
  assert( !IsPinControlledByPio( pioPtr, PIN_NUMBER ) );

  // The pull-ups can be enabled or disabled regardless of the pin configuration.
  // The pull-up should be active.
  return IsPullUpEnabled( pioPtr, PIN_NUMBER );
}


// ------- Configure the UART connected to the AVR controller -------

void InitDebugConsoleUart ( const bool enableRxInterrupt ) throw()
{
  VERIFY( pio_configure( PIOA, PIO_PERIPH_A,
                         PIO_PA8A_URXD | PIO_PA9A_UTXD, PIO_DEFAULT ) );

  // Enable the pull-up resistor for RX0.
  pio_pull_up( PIOA, PIO_PA8A_URXD, ENABLE ) ;

  InitSerialPort( enableRxInterrupt );
}


void PrintPanicMsg ( const char * const msg ) throw()
{
  // This routine is called with interrupts disabled and should rely
  // on as little other code as possible.
  SerialSyncWriteStr( EOL );
  SerialSyncWriteStr( "PANIC: " );
  SerialSyncWriteStr( msg );
  SerialSyncWriteStr( EOL );

  // Here it would be a good place to print a stack backtrace,
  // but I have not been able to figure out yet how to do that
  // with the ARM Thumb platform.
}


// Perform some assorted checks on start-up.

void StartUpChecks ( void ) throw()
{
  assert( IsJtagTdoPullUpActive() );

  // Check that the brown-out detector is active.
  #ifndef NDEBUG
    const uint32_t supcMr = SUPC->SUPC_MR;
    assert( ( supcMr & SUPC_MR_BODDIS   ) == SUPC_MR_BODDIS_ENABLE   );
    assert( ( supcMr & SUPC_MR_BODRSTEN ) == SUPC_MR_BODRSTEN_ENABLE );
  #endif


  // This is actually not specific to Arduino Due, but is common to all Cortex-M3 cores.

  // SerialPrintf( "CCR: 0x%08X" EOL, unsigned( SCB->CCR ) );

  #ifdef __ARM_FEATURE_UNALIGNED
    assert( 0 == ( SCB->CCR & SCB_CCR_UNALIGN_TRP_Msk ) );
  #else
    assert( 0 != ( SCB->CCR & SCB_CCR_UNALIGN_TRP_Msk ) );
    #error "We normally do not expect this scenario."
  #endif
}


void PrintFirmwareSegmentSizes ( void ) throw()
{
  const unsigned codeSize     = unsigned( uintptr_t( &__etext      ) - uintptr_t( &_sfixed        ) );
  const unsigned initDataSize = unsigned( uintptr_t( &__data_end__ ) - uintptr_t( &__data_start__ ) );
  const unsigned bssDataSize  = unsigned( uintptr_t( &__bss_end__  ) - uintptr_t( &__bss_start__  ) );

  // This alternative uses vsnprintf() and brings in more of the C runtime library (makes the firmware bigger).
  //
  // SerialPrintf( "Code size: %u, initialised data size: %u, BSS size: %u." EOL,
  //               codeSize,
  //               initDataSize,
  //               bssDataSize );

  SerialSyncWriteStr( "Code size: 0x" );
  SerialSyncWriteUint32Hex( codeSize );
  SerialSyncWriteStr( ", initialised data size: 0x" );
  SerialSyncWriteUint32Hex( initDataSize );
  SerialSyncWriteStr( ", BSS size: 0x" );
  SerialSyncWriteUint32Hex( bssDataSize );
  SerialSyncWriteStr( "." EOL );
}

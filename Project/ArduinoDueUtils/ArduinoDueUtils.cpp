
#include "ArduinoDueUtils.h"  // The include file for this module should come first.

#include <BareMetalSupport/IoUtils.h>
#include <BareMetalSupport/SerialPortUtils.h>
#include <BareMetalSupport/DebugConsoleEol.h>


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

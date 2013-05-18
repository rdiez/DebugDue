
#include "Led.h"  // The include file for this module should come first.

#include <pio.h>

#include <BareMetalSupport/IoUtils.h>


#define LED_PIN  uint8_t(27)


void ConfigureLedPort ( void )
{
    // When the board starts, or when the Reset key is held down, the LED is on by default.
    // This routine turns it off.
    pio_set_output( PIOB, BV(LED_PIN), LOW, DISABLE, DISABLE );
}


void SetLed ( const bool on )
{
  SetOutputDataDrivenOnPin( PIOB, LED_PIN, on );
}


void ToggleLed ( void )
{
  SetOutputDataDrivenOnPin( PIOB, LED_PIN, ! IsInputPinHigh( PIOB, LED_PIN ) );
}

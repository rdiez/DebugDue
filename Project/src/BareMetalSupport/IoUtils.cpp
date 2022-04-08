
#include "IoUtils.h"  // Include file for this module comes first.

uint8_t GetArduinoDuePinNumberFromPio ( const Pio * const pioPtr,
                                               const uint8_t pinNumber  // 0-31
                                      ) throw()
{
  switch ( GetPioIdFromPtr( pioPtr ) )
  {
  case ID_PIOA:
    switch( pinNumber )
    {
    case 19: return 42;
    case 20: return 43;

    default:
      // Not all pins have been implemented in this routine yet.
      assert( false );
      return 0;
    }

  case ID_PIOB:
    switch( pinNumber )
    {
    default:
      // Not all pins have been implemented in this routine yet.
      assert( false );
      return 0;
    }

  case ID_PIOC:
    switch( pinNumber )
    {
    case 12: return 51;
    case 13: return 50;
    case 14: return 49;
    case 15: return 48;
    case 16: return 47;
    case 17: return 46;
    case 18: return 45;
    case 19: return 44;
    default:
      // Not all pins have been implemented in this routine yet.
      assert( false );
      return 0;
    }

  case ID_PIOD:
    switch( pinNumber )
    {
    default:
      // Not all pins have been implemented in this routine yet.
      assert( false );
      return 0;
    }

  default:
    assert( false );
    return 0;
  }
}

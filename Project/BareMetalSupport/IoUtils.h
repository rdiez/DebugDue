
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
#include <assert.h>

#include "AssertionUtils.h"

#include <sam3xa.h>
#include <pio.h>
#include <pmc.h>


// Empirical tests show that using bit banding yields significantly lower performance.
// Either the GCC 4.7.3 does not optimise it properly, or bit-banding carries a CPU performance penalty,
// as writes are converted to atomic read-modify-write operations. Or maybe both reasons are true.
#define USE_BIT_BANDING_WHEN_WRITING false
#define USE_BIT_BANDING_WHEN_READING false

// Parallel access is only faster if combined with USE_BIT_BANDING.
// The corresponding PIO_OWER bit should be set to 1 then for the pins written.
#define USE_PARALLEL_ACCESS false


inline uint32_t BV ( const uint32_t v )
{
  assert( v < 32 );
  return 1 << v;
}


inline bool IsKnownPioPtr ( const Pio * const pioPtr )
{
  if ( pioPtr == PIOA ||
       pioPtr == PIOB ||
       pioPtr == PIOC ||
       pioPtr == PIOD )
  {
    return true;
  }
  else
  {
    return false;
  }
}


inline uint32_t GetPioIdFromPtr ( const Pio * const pioPtr )
{
  assert( IsKnownPioPtr( pioPtr ) );

  const uint32_t pioNumber = ( uintptr_t( pioPtr ) - uintptr_t( PIOA ) ) / PIO_DELTA;

  return ID_PIOA + pioNumber;
}


// In order to read from a pin, the PIO clock must have been enabled.

inline bool IsPioClockEnabled ( const Pio * const pioPtr )
{
  return 0 != pmc_is_periph_clk_enabled( GetPioIdFromPtr( pioPtr ) );
}


inline volatile uint32_t * GetPioBitBandAddr ( const volatile void * const pioAddr,
                                               const uint8_t bitNumber  // 0-31.
                                             )
{
  assert( bitNumber < 32 );

  const uintptr_t BIT_BAND_REGION_FIRST_ADDR = 0x40000000;
  const uintptr_t BIT_BAND_REGION_LAST_ADDR  = 0x400FFFFF;

  const uintptr_t BIT_BAND_ALIAS_FIRST_ADDR = 0x42000000;
  const uintptr_t BIT_BAND_ALIAS_LAST_ADDR  = 0x43FFFFFF;

  UNUSED_IN_RELEASE( BIT_BAND_REGION_LAST_ADDR );
  UNUSED_IN_RELEASE( BIT_BAND_ALIAS_LAST_ADDR );

  const uintptr_t addr = uintptr_t( pioAddr );

  assert( addr >= BIT_BAND_REGION_FIRST_ADDR &&
          addr <= BIT_BAND_REGION_LAST_ADDR );

  const uintptr_t offset = ( addr - BIT_BAND_REGION_FIRST_ADDR ) * 32 + (bitNumber * 4);
  const uintptr_t res = BIT_BAND_ALIAS_FIRST_ADDR + offset;

  assert( res >= BIT_BAND_ALIAS_FIRST_ADDR &&
          res <= BIT_BAND_ALIAS_LAST_ADDR );

  return (volatile uint32_t *) res;
}


inline bool IsPinControlledByPio ( const Pio * const pioPtr,
                                   const uint8_t pinNumber // 0-31.
                                 )
{
  assert( IsKnownPioPtr( pioPtr ) );

  // We could use bit banding here too.

  const uint32_t ctrlStatus = pioPtr->PIO_PSR;
  const bool isCtrlActive = 0 != ( ctrlStatus & BV(pinNumber) );
  return isCtrlActive;
}


inline bool IsPullUpEnabled ( const Pio * const pioPtr,
                              const uint8_t pinNumber  // 0-31.
                            )
{
  assert( IsKnownPioPtr( pioPtr ) );

  // We could use bit banding here too.

  const uint32_t pullupStatus = pioPtr->PIO_PUSR;
  const bool isPullUpActive = 0 == ( pullupStatus & BV(pinNumber) );
  return isPullUpActive;
}


inline bool IsParallelAccessEnabledForPin ( Pio * const pioPtr,
                                            const uint8_t pinNumber  // 0-31.
                                          )
{
  assert( IsKnownPioPtr( pioPtr ) );

  // We could use bit banding here too.

  return 0 != ( pioPtr->PIO_OWSR & BV(pinNumber) );
}


inline void SetOutputDataDrivenOnPinToHigh ( Pio * const pioPtr,
                                             const uint8_t pinNumber  // 0-31.
                                           )
{
  assert( IsKnownPioPtr( pioPtr ) );

  if ( USE_BIT_BANDING_WHEN_WRITING )
  {
    if ( USE_PARALLEL_ACCESS )
    {
      assert( IsParallelAccessEnabledForPin( pioPtr, pinNumber ) );

      // SetPin() and ClearPin() use the same PIO_ODSR address, which can lead
      // to a better optimisation when clearing and setting the same bit in a row.
      volatile uint32_t * const bitBandPtr = GetPioBitBandAddr( &pioPtr->PIO_ODSR, pinNumber );

      *bitBandPtr = 1;
    }
    else
    {
      volatile uint32_t * const bitBandPtr = GetPioBitBandAddr( &pioPtr->PIO_SODR, pinNumber );
      *bitBandPtr = 1;
    }
  }
  else
  {
    pioPtr->PIO_SODR = BV( pinNumber );
  }
}


inline void SetOutputDataDrivenOnPinToLow ( Pio * const pioPtr,
                                            const uint8_t pinNumber  // 0-31.
                                          )
{
  assert( IsKnownPioPtr( pioPtr ) );

  if ( USE_BIT_BANDING_WHEN_WRITING )
  {
    if ( USE_PARALLEL_ACCESS )
    {
      assert( IsParallelAccessEnabledForPin( pioPtr, pinNumber ) );

      // SetPin() and ClearPin() use the same PIO_ODSR address, which can lead
      // to a better optimisation when clearing and setting the same bit in a row.
      volatile uint32_t * const bitBandPtr = GetPioBitBandAddr( &pioPtr->PIO_ODSR, pinNumber );
      *bitBandPtr = 0;
    }
    else
    {
      volatile uint32_t * const bitBandPtr = GetPioBitBandAddr( &pioPtr->PIO_CODR, pinNumber );
      *bitBandPtr = 1;
    }
  }
  else
  {
    pioPtr->PIO_CODR = BV( pinNumber );
  }
}


inline void SetOutputDataDrivenOnPin ( Pio * const pioPtr,
                                       const uint8_t pinNumber,  // 0-31.
                                       const bool isPinSet
                                     )
{
  if ( USE_BIT_BANDING_WHEN_WRITING && USE_PARALLEL_ACCESS )
  {
    assert( IsParallelAccessEnabledForPin( pioPtr, pinNumber ) );

    volatile uint32_t * const bitBandPtr = GetPioBitBandAddr( &pioPtr->PIO_ODSR, pinNumber );

    *bitBandPtr = isPinSet ? 1 : 0;
  }
  else
  {
    if ( isPinSet )
      SetOutputDataDrivenOnPinToHigh( pioPtr, pinNumber );
    else
      SetOutputDataDrivenOnPinToLow( pioPtr, pinNumber );
  }
}


inline bool GetOutputDataDrivenOnPin ( const Pio * const pioPtr,
                                       const uint8_t pinNumber  // 0-31.
                                     )
{
  if ( USE_BIT_BANDING_WHEN_READING )
  {
    const volatile uint32_t * const bitBandPtr = GetPioBitBandAddr( &pioPtr->PIO_ODSR, pinNumber );
    const uint32_t val = *bitBandPtr;
    assert( val == 0 || val == 1 );
    return val != 0;
  }
  else
  {
    return ( pioPtr->PIO_ODSR & BV(pinNumber) ) ? true : false;
  }
}


inline bool IsInputPinHigh ( const Pio * const pioPtr,
                             const uint8_t pinNumber  // 0-31.
                           )
{
  assert( IsPioClockEnabled( pioPtr ) );

  if ( USE_BIT_BANDING_WHEN_READING )
  {
    const volatile uint32_t * const bitBandPtr = GetPioBitBandAddr( &pioPtr->PIO_PDSR, pinNumber );
    const uint32_t val = *bitBandPtr;
    assert( val == 0 || val == 1 );
    return val != 0;
  }
  else
  {
    return ( pioPtr->PIO_PDSR & BV(pinNumber) ) ? true : false;
  }
}


uint8_t GetArduinoDuePinNumberFromPio ( const Pio * pioPtr, uint8_t pinNumber );

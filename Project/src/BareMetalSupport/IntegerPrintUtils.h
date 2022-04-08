
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


// Converts a number in the range [0-15] to an uppercase hex digit.

inline char ConvertDigitToHex ( const unsigned digitValue,
                                const bool useLowercaseHexChars ) throw()
{
  assert( digitValue <= 15 );

  if ( digitValue <= 9 )
  {
    return (char)( '0' + digitValue );
  }
  else
  {
    if ( useLowercaseHexChars )
    {
      return (char)( 'a' + digitValue - 10 );
    }
    else
    {
      return (char)( 'A' + digitValue - 10 );
    }
  }
}

#define CONVERT_UINT32_TO_HEX_BUFSIZE ( 8 + 1 )

void ConvertUint32ToHex ( uint32_t val, char * buffer, bool useLowercaseHexChars ) throw();


//------------------------------------------------------------------------
//
// Converts an integer number to its shortest decimal representation.
// It's of course faster than printf(), and also faster than itoa(),
// because for some reason itoa() internally uses multithreaded locks.
//
// Pass in a buffer of at least size CONVERT_TO_DEC_BUF_SIZE.
//
// Returns the number of characters written to the buffer,
// without taking into account the NULL character appended at the end.
//

#define CONVERT_TO_DEC_BUF_SIZE 28  // Max unsigned 64-bit number is 18446744073709551615 (20 digits), plus NULL terminator (1),
                                    // negative '-' prefix if necessary for signed numbers (1) und thousand separators (6).

// This version generates thousand separators.
// Note that the number ends up at the end of the buffer, and not at the beginning.
// Thefore, the pointer to the number's beginning is returned.
char * convert_unsigned_to_dec_th ( uint64_t val,
                                    char * buffer,
                                    char thousandSepChar ) throw();

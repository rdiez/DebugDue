
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

#include <Misc/AssertionUtils.h>

#include "IntegerPrintUtils.h"  // Include file for this module comes first.


static const char NULL_CHAR = '\0';


//------------------------------------------------------------------------
// The buffer must be at least CONVERT_UINT32_TO_HEX_BUFSIZE bytes long.

void ConvertUint32ToHex ( const uint32_t val,
                          char * const buffer,
                          const bool useLowercaseHexChars ) throw()
{
  const unsigned CHAR_COUNT = sizeof( val ) * 2;
  STATIC_ASSERT( CONVERT_UINT32_TO_HEX_BUFSIZE == CHAR_COUNT + 1, "Wrong buffer size." );

  uint32_t v = val;

  for ( unsigned i = 0; i < CHAR_COUNT; ++i )
  {
    const unsigned highest_nibble = v >> 28;

    buffer[i] = ConvertDigitToHex( highest_nibble, useLowercaseHexChars );

    v <<= 4;
  }

  assert( v == 0 );

  buffer[CHAR_COUNT] = '\0';
}


char * convert_unsigned_to_dec_th ( uint64_t val,
                                    char * const buffer,
                                    const char thousandSepChar ) throw()
{
  static_assert( sizeof(val) <= 8, "" );
  // Otherwise, we need a higher character count here:
  static_assert( CONVERT_TO_DEC_BUF_SIZE == 28, "" );


  // Short-circuit 0, as it's a very common value.

  if ( val == 0 )
  {
    buffer[0] = '0';
    buffer[1] = NULL_CHAR;
    return buffer;
  }


  // Start at the end of the buffer, fill the buffer backwards.

  char * p = buffer + CONVERT_TO_DEC_BUF_SIZE - 1;

  int i = 0;

  *p = NULL_CHAR;

  do
  {
    if ( i % 3 == 0 && i != 0 )
    {
      --p;
      *p = thousandSepChar;
    }

    --p;
    *p = char( '0' + val % 10 );
    val /= 10;
    ++i;
  }
  while ( val != 0 );


  assert( p >= buffer );

  return p;
}

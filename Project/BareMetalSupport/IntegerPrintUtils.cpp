
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


#include "IntegerPrintUtils.h"  // Include file for this module comes first.

#include "AssertionUtils.h"


//------------------------------------------------------------------------
// The buffer must be at least CONVERT_UINT32_TO_HEX_BUFSIZE bytes long.

void ConvertUint32ToHex ( const uint32_t val,
                          char * const buffer,
                          const bool useLowercaseHexChars )
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

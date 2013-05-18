
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


// Include this header file only once.
#ifndef BMS_INTEGER_PRINT_UTILS_H_INCLUDED
#define BMS_INTEGER_PRINT_UTILS_H_INCLUDED

#include <stdint.h>
#include <assert.h>


// Converts a number in the range [0-15] to an uppercase hex digit.

inline char ConvertDigitToHex ( const unsigned digitValue,
                                const bool useLowercaseHexChars )
{
  assert( digitValue <= 15 );

  if ( digitValue <= 9 )
  {
    return (char)( '0' + digitValue );
  }
  else
  {
    if ( useLowercaseHexChars )
      return (char)( 'a' + digitValue - 10 );
    else
      return (char)( 'A' + digitValue - 10 );
  }
}

#define CONVERT_UINT32_TO_HEX_BUFSIZE ( 8 + 1 )

void ConvertUint32ToHex ( uint32_t val, char * buffer, bool useLowercaseHexChars );

#endif  // Include this header file only once.

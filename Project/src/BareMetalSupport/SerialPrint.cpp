
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


#include "SerialPrint.h"  // The include file for this module should come first.

#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>
#include <stdexcept>

#include "SerialPortAsyncTx.h"


void SerialPrintStr ( const char * const msg )
{
  SendSerialPortAsyncData( msg, strlen(msg) );
}


void SerialPrintf ( const char * formatStr, ... )
{
  va_list argList;
  va_start( argList, formatStr );

  SerialPrintV( formatStr, argList );

  va_end( argList );
}


// This routine could be improved in many ways:
// - Make it faster by building a complete line and sending it at once.
// - Provide memory addresses and/or offsets on the left.
// - Provide an ASCII dump on the right.
// - Use different data sizes (8 bits, 16 bits, 32 bits).

void SerialPrintHexDump ( const void * const ptr,
                          const size_t byteCount,
                          const char * const endOfLineChars )
{
  assert( byteCount > 0 );

  const uint8_t * const bytePtr = static_cast< const uint8_t * >( ptr );

  unsigned lineElemCount = 0;

  for ( size_t i = 0; i < byteCount; ++i )
  {
    if ( lineElemCount == 20 )
    {
      lineElemCount = 0;
      SerialPrintStr( endOfLineChars );
    }
    const uint8_t b = bytePtr[ i ];
    SerialPrintf( "0x%02" PRIX8 " ", b );
    ++lineElemCount;
  }

  SerialPrintStr( endOfLineChars );
}


static const char TRUNCATION_SUFFIX[] = "[...]";
static const size_t TRUNCATION_SUFFIX_LEN = sizeof( TRUNCATION_SUFFIX ) - 1;

void SerialPrintV ( const char * const formatStr, va_list argList )
{
  // POSSIBLE OPTIMISATION: It may be worth trying to print directly to the Tx Buffer
  // and only resort to the stack-based buffer if there is not enough contiguous space
  // in the Tx Buffer. Or maybe there is a variant of vsnprintf() which does not take
  // a buffer to write to, but a call-back routine instead.

  char buffer[ MAX_SERIAL_PRINT_LEN + 1 ];

  const int len = vsnprintf( buffer, MAX_SERIAL_PRINT_LEN + 1, formatStr, argList );

  if ( len < 0 )
  {
    // I do not think that vsnprintf would ever fail, but you never know.
    throw std::runtime_error( "vsnprintf failed." );
  }
  else if ( len >= MAX_SERIAL_PRINT_LEN + 1 )  // If the string needs to be truncated ...
  {
    assert( false );  // The caller should strive to avoid any truncation.

    // We don't actually need to assert on this, but I just want to be sure I know what happens in this case.
    assert( buffer[ MAX_SERIAL_PRINT_LEN ] == 0 );

    SendSerialPortAsyncData( buffer, MAX_SERIAL_PRINT_LEN );
    SendSerialPortAsyncData( TRUNCATION_SUFFIX, TRUNCATION_SUFFIX_LEN );
    SendSerialPortAsyncData( GetSerialPortEol(), strlen( GetSerialPortEol() ) );
  }
  else
  {
    SendSerialPortAsyncData( buffer, size_t( len ) );
  }
}


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


#include "UsbBuffers.h"  // The include file for this module should come first.

#include <stdarg.h>
#include <stdio.h>

#include "Globals.h"


// It is hard to keep the last discarded characters, and there is often an end-of-line sequence there.
// As a (cheap) work-around, insert always an EOL.
static const char TRUNCATION_SUFFIX[] = "[...]" EOL;

static void UsbPrintV ( CUsbTxBuffer * const txBuffer, const char * const formatStr, va_list argList )
{
  const size_t TRUNCATION_SUFFIX_LEN = sizeof( TRUNCATION_SUFFIX ) - 1;

  char buffer[ MAX_USB_PRINT_LEN + TRUNCATION_SUFFIX_LEN + 1 ];

  const int len = vsnprintf( buffer, MAX_USB_PRINT_LEN + 1, formatStr, argList );

  // If the string was truncated, append the truncation suffix.
  // Leave the last 3 characters in place, so that any end-of-line characters remain.

  if ( len >= MAX_USB_PRINT_LEN + 1 )
  {
    assert( false );  // We should not need to truncate any lines.

    assert( buffer[ MAX_USB_PRINT_LEN ] == 0 );
    memcpy( &buffer[ MAX_USB_PRINT_LEN ], TRUNCATION_SUFFIX, TRUNCATION_SUFFIX_LEN + 1 );
    assert( strlen(buffer) == MAX_USB_PRINT_LEN + TRUNCATION_SUFFIX_LEN );
  }

  txBuffer->WriteString( buffer );
}


void UsbPrint ( CUsbTxBuffer * const txBuffer, const char * formatStr, ... )
{
  va_list argList;
  va_start( argList, formatStr );

  UsbPrintV( txBuffer, formatStr, argList );

  va_end( argList );
}


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

#include <stdio.h>
#include <stdexcept>

#include <BareMetalSupport/DebugConsoleEol.h>

#include "Globals.h"


static void SendData ( CUsbTxBuffer * const txBuffer, const uint8_t * data, const size_t dataLen )
{
  if ( dataLen == 0 )
  {
    // This could happen, but is unusual.
    assert( false );
    return;
  }

  if ( dataLen > txBuffer->GetFreeCount() )
  {
    // The caller should always make sure that there is enough space in the Tx Buffer
    // before calling this routine. Otherwise, all or part of the outgoing text
    // will be dropped, and the user may get no hint whatsoever about what just happened.
    //
    // However, there are some situations where this is hard to implement, or where
    // the risk of data loss is acceptable for performance reasons.
    //
    // I have left an assert in place because data truncation should be rare and
    // you should strive to avoid it.
    //
    // Remember that, with the current implementation, data does not just get truncated
    // at this point, but the whole connection gets reset.
    assert( false );

    throw std::runtime_error( "Tx Buffer overflow." );
  }

  txBuffer->WriteElemArray( data, dataLen );
}


// It is hard to keep the last discarded characters, and there is often an end-of-line sequence there.
// As a (cheap) work-around, insert always an EOL.
static const char TRUNCATION_SUFFIX[] = "[...]" EOL;
static const size_t TRUNCATION_SUFFIX_LEN = sizeof( TRUNCATION_SUFFIX ) - 1;

void UsbPrintV ( CUsbTxBuffer * const txBuffer, const char * const formatStr, va_list argList )
{
  // POSSIBLE OPTIMISATION: It may be worth trying to print directly to the Tx Buffer
  // and only resort to the stack-based buffer if there is not enough contiguous space
  // in the Tx Buffer. Or maybe there is a variant of vsnprintf() which does not take
  // a buffer to write to, but a call-back routine instead.

  char buffer[ MAX_USB_PRINT_LEN + 1 ];

  const int len = vsnprintf( buffer, MAX_USB_PRINT_LEN + 1, formatStr, argList );

  if ( len < 0 )
  {
    // I do not think that vsnprintf would ever fail, but you never know.
    throw std::runtime_error( "vsnprintf failed." );
  }
  else if ( len >= MAX_USB_PRINT_LEN + 1 )  // If the string needs to be truncated ...
  {
    assert( false );  // The caller should strive to avoid any truncation.

    // We don't actually need to assert on this, but I just want to be sure I know what happens in this case.
    assert( buffer[ MAX_USB_PRINT_LEN ] == 0 );

    SendData( txBuffer, (const uint8_t *)buffer, MAX_USB_PRINT_LEN );
    SendData( txBuffer, (const uint8_t *)TRUNCATION_SUFFIX, TRUNCATION_SUFFIX_LEN );
  }
  else
  {
    SendData( txBuffer, (const uint8_t *)buffer, size_t( len ) );
  }
}


void UsbPrintf ( CUsbTxBuffer * const txBuffer, const char * formatStr, ... )
{
  va_list argList;
  va_start( argList, formatStr );

  UsbPrintV( txBuffer, formatStr, argList );

  va_end( argList );
}


void UsbPrintStr ( CUsbTxBuffer * const txBuffer, const char * str )
{
  SendData( txBuffer, (const uint8_t *)str, strlen( str ) );
}

void UsbPrintChar ( CUsbTxBuffer * const txBuffer, const char c )
{
  SendData( txBuffer, (const uint8_t *)&c, sizeof(c) );
}

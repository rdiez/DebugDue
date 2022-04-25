
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


#include "BusPirateBinaryMode.h"  // The include file for this module should come first.

#include <assert.h>
#include <stdexcept>

#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/IoUtils.h>
#include <Misc/AssertionUtils.h>

#include "BusPirateConnection.h"


#ifndef NDEBUG
  static bool s_wasInitialised = false;
#endif


static void SendBinaryModeWelcome ( CUsbTxBuffer * const txBuffer )
{
  UsbPrintStr( txBuffer, "BBIO1" );
}


void BusPirateBinaryMode_ProcessData ( CUsbRxBuffer * const rxBuffer, CUsbTxBuffer * const txBuffer )
{
  assert( s_wasInitialised );

  // Speed is not important here (yet), so we favor simplicity. We only process one byte at a time,
  // otherwise we would have to worry about whether there is enough space in the tx buffer
  // for the next command reply.

  if ( rxBuffer->IsEmpty() || !txBuffer->IsEmpty() )
    return;

  const uint8_t byte = rxBuffer->ReadElement();

  switch ( byte )
  {
  case BIN_MODE_CHAR:
    SendBinaryModeWelcome( txBuffer );
    break;

  case OOCD_MODE_CHAR:
    ChangeBusPirateMode( bpOpenOcdMode, txBuffer );
    break;

  case 0x0F:
    ChangeBusPirateMode( bpConsoleMode, txBuffer );
    break;

  default:
    // The protocol does not allow for any better error indication.
    SendBinaryModeWelcome( txBuffer );
    break;
  }
}


void BusPirateBinaryMode_Init ( CUsbTxBuffer * const txBuffer )
{
  assert( !s_wasInitialised );

  #ifndef NDEBUG
    s_wasInitialised = true;
  #endif

  // Note that there is an error path that might land here with a non-empty Tx Buffer.
  SendBinaryModeWelcome( txBuffer );
}

void BusPirateBinaryMode_Terminate ( void )
{
  assert( s_wasInitialised );

  #ifndef NDEBUG
   s_wasInitialised = false;
  #endif
}

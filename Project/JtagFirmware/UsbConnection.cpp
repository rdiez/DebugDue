
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


#include "UsbConnection.h"  // The include file for this module should come first.

#include "UsbBuffers.h"

#include <interrupt.h>

#include <string.h>
#include <stdexcept>

#include <BareMetalSupport/Uptime.h>
#include <BareMetalSupport/DebugConsole.h>
#include <BareMetalSupport/AssertionUtils.h>
#include <BareMetalSupport/TriggerMainLoopIteration.h>

#include "UsbSupport.h"
#include "Globals.h"
#include "BusPirateConnection.h"

#include <udi_cdc.h>


enum ConnectionStatusEnum
{
  csNoConnection = 1,
  csInitialDelay,
  csStable,
  csLastRxDataAfterConnectionLost  // Unfortunately, we can see that the connection has been lost
                                   // before we process the last incoming data.
};

static ConnectionStatusEnum s_connectionStatus = csNoConnection;

static CUsbTxBuffer s_usbTxBuffer;
static CUsbRxBuffer s_usbRxBuffer;


static void ResetBuffers ( void )
{
  s_usbTxBuffer.Reset();
  s_usbRxBuffer.Reset();
}


static void UsbConnectionEstablished ( void )
{
  DbgconPrintStr( "Connection opened on the native USB port." EOL );

  // DbgconPrint( "Rx buffer size: %u, Tx buffer size: %u" EOL, USB_RX_BUFFER_SIZE, USB_TX_BUFFER_SIZE );

  ResetBuffers();
  BusPirateConnection_Init( &s_usbTxBuffer );
}


static void UsbConnectionLost ( void )
{
  DbgconPrintStr( "Connection lost on the native USB port." EOL );

  BusPirateConnection_Terminate();
  ResetBuffers();
}


// If you connect to the USB port with a tool like socat, and the pull the cable,
// the next time you connect the cable and start socat again, you'll get one or two brief
// connections before the final one is stable. Therefore, I have placed a short delay here,
// so that connections are only considered stable after the delay.
static const uint32_t USB_CONNECTION_STABLE_DELAY = 50;  // In milliseconds.
static uint64_t s_lastReferenceTimeForUsbOpen = 0;


static bool SendData ( void )
{
  bool wasAtLeastOneByteTransferred = false;

  for ( ; ; )
  {
    uint32_t availableByteCount;
    const uint8_t * const readPtr = s_usbTxBuffer.GetReadPtr( &availableByteCount );

    if ( availableByteCount == 0 )
      break;

    const uint32_t remainingCount = udi_cdc_write_buf( readPtr, availableByteCount );

    assert( remainingCount <= availableByteCount );

    const uint32_t writtenCount = availableByteCount - remainingCount;

    if ( writtenCount == 0 )
    {
      break;
    }

    s_usbTxBuffer.ConsumeReadElements( writtenCount );
    wasAtLeastOneByteTransferred = true;
  }

  return wasAtLeastOneByteTransferred;
}



static bool ReceiveData ( void )
{
  bool wasAtLeastOneByteTransferred = false;

  for ( ; ; )
  {
    uint32_t byteCountToWrite;
    uint8_t * const writePtr = s_usbRxBuffer.GetWritePtr( &byteCountToWrite );

    if ( byteCountToWrite == 0 )
      break;

    const uint32_t inUsbBufferCount = udi_cdc_get_nb_received_data();

    if ( inUsbBufferCount == 0 )
      break;

    const uint32_t toReceiveCount = MinFrom( inUsbBufferCount, byteCountToWrite );

    const uint32_t remainingCount = udi_cdc_read_buf( writePtr, toReceiveCount );

    assert( remainingCount <= toReceiveCount );

    const size_t readCount = toReceiveCount - remainingCount;

    if ( readCount == 0 )
    {
      assert( false );
      break;
    }

    s_usbRxBuffer.CommitWrittenElements( readCount );
    wasAtLeastOneByteTransferred = true;
  }

  return wasAtLeastOneByteTransferred;
}


static void ServiceUsbConnectionData ( const uint64_t currentTime )
{
  // We could write here a loop in order to process as much data as we can,
  // but we don't want to starve the main loop for too long.
  //
  // We must call the processing routine at least once, even if no data was sent or received,
  // in case there is a time-out to trigger.

  const bool atLeastOneByteReceived = ReceiveData();

  if ( s_connectionStatus == csLastRxDataAfterConnectionLost && !atLeastOneByteReceived )
  {
    s_connectionStatus = csNoConnection;
    UsbConnectionLost();
    return;
  }

  BusPirateConnection_ProcessData( &s_usbRxBuffer, &s_usbTxBuffer, currentTime );

  if ( s_connectionStatus == csLastRxDataAfterConnectionLost )
  {
    // The connection is not there any more, drop all eventual data to send.
    s_usbTxBuffer.Reset();

    // Continue reading until the end of data, when we will declare the connection as lost.
    TriggerMainLoopIteration();
  }
  else
  {
    const bool atLeastOneByteSent = SendData();

    // If we have sent at least one byte of data, then there is more space available in the tx buffer,
    // which means that perhaps the next command already waiting in the rx buffer could be processed
    // straight away, for its reply would fit now in the tx buffer.

    if ( atLeastOneByteSent )
      TriggerMainLoopIteration();
  }
}


void ServiceUsbConnection ( const uint64_t currentTime )
{
  try
  {
    switch ( s_connectionStatus )
    {
    case csNoConnection:
      if ( IsUsbConnectionOpen() )
      {
        s_lastReferenceTimeForUsbOpen = currentTime;
        s_connectionStatus = csInitialDelay;
      }
      break;

    case csInitialDelay:
      if ( HasUptimeElapsedMs( currentTime, s_lastReferenceTimeForUsbOpen, USB_CONNECTION_STABLE_DELAY ) )
      {
        s_connectionStatus = csStable;
        UsbConnectionEstablished();
      }
      break;

    case csStable:
      if ( !IsUsbConnectionOpen() )
      {
        s_connectionStatus = csLastRxDataAfterConnectionLost;
      }
      ServiceUsbConnectionData( currentTime );
      break;

    case csLastRxDataAfterConnectionLost:
      ServiceUsbConnectionData( currentTime );
      break;

    default:
      assert( false );
      break;
    }
  }
  catch ( const std::exception & e )
  {
    // Here we could close and reopen the USB connection (the virtual serial port),
    // but I do not know yet how to do that from this side.

    DbgconPrintStr( "Error servicing the USB connection: " );
    DbgconPrintStr( e.what() );
    DbgconPrintStr( EOL );
  }
  catch ( ... )
  {
    DbgconPrintStr( "Error servicing the USB connection: " );
    DbgconPrintStr( "<unexpected C++ exception>" );
    DbgconPrintStr( EOL );
  }
}

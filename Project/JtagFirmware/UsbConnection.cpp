
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
#include <BareMetalSupport/SerialPrint.h>
#include <BareMetalSupport/AssertionUtils.h>
#include <BareMetalSupport/MainLoopSleep.h>

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
  SerialPrintStr( "Connection opened on the native USB port." EOL );

  // SerialPrint( "Rx buffer size: %u, Tx buffer size: %u" EOL, unsigned(USB_RX_BUFFER_SIZE), unsigned(USB_TX_BUFFER_SIZE) );

  ResetBuffers();
  BusPirateConnection_Init( &s_usbTxBuffer );
}


static void UsbConnectionLost ( void )
{
  SerialPrintStr( "Connection lost on the native USB port." EOL );

  BusPirateConnection_Terminate();
  ResetBuffers();

  // Note that at this point there may still be outgoing data in the USB buffer inside the Atmel Software Framework
  // (or may be that is directly the chip's USB hardware buffer). If the USB cable was not removed, this data
  // will not be lost. I have tested that data written here with udi_cdc_write_buf() gets received twice
  // by the next program that connects to the CDC serial port, which seems strange. I guess the host side (Linux)
  // will buffer up any received data and then deliver it to the next client that connects to CDC the serial port,
  // as long as the USB cable remains put. I could not find any ASF API near udi_cdc_write_buf() in order
  // to discard any outgoing data from the ASF buffer.
  //
  // For the reasons above, I guess that any serial port client on the host side (Linux) should read and
  // discard all stale data upon connect. After all, the Bus Pirate protocol is of the master/slave type,
  // so the client should have nothing to say until the master sends the first command.
  //
  // Enabling the condition below will generate stale data for test purposes, but I am not sure
  // whether this is an ASF bug. After all, any data written after getting the connection lost notification
  // should be automatically discarded.
  //
  // Another way to generate stale data is with this bash command:
  //     printf "help\r">/dev/jtagdue1
  // The next time you connect to /dev/jtagdue1 you will get the help text,
  // you can test it with this bash command:
  //     cat /dev/jtagdue1

  if ( false )
  {
    udi_cdc_write_buf( "stale-test-data", 15 );
  }
}


// If you connect to the USB port with a Linux tool like socat, and the pull the cable,
// the next time you connect the cable and start socat again, you'll get one or two brief
// connections before the final one is stable. Therefore, I have implemented a delay,
// so that connections are only considered stable after a short time.
// A delay of 50 milliseconds is usually fine.
//
// Under Windows Vista I am getting a spurious connection with a simular scenario: Connect to
// the virtual serial port with Putty, disconnect the USB cable and connect it again.
// A delay of even 150 milliseconds is not enough to suppress it, and I don't want to implement
// a longer delay, so I decided to live with it. After all, it's not a big deal.
//
// On Windows Vista there is some system error that prevents you from connecting to the serial port
// if you reconnect the USB cable while the previous Putty session is still open.
// You need to close Putty before reconnecting the cable again.

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

    if ( false )
    {
      SerialPrintStr( "Data sent:" EOL );
      SerialPrintHexDump( readPtr, writtenCount, EOL );
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


    // Trace the full data received.

    if ( false )
    {
      SerialPrintStr( "Data received:" EOL );
      SerialPrintHexDump( writePtr, readCount, EOL );
    }


    // Trace only the packet length.

    if ( false )
    {
      SerialPrintf( "%u" EOL, unsigned( readCount ) );
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
    WakeFromMainLoopSleep();
  }
  else
  {
    const bool atLeastOneByteSent = SendData();

    // If we have sent at least one byte of data, then there is more space available in the tx buffer,
    // which means that perhaps the next command already waiting in the rx buffer could be processed
    // straight away, for its reply would fit now in the tx buffer.

    if ( atLeastOneByteSent )
      WakeFromMainLoopSleep();
  }
}


static void HandleError ( const char * const errMsg )
{
  // This kind of error should never happen, because the user will not get
  // a proper error indication on the communication channel that he was using.

  // Here we could close and reopen the USB connection (the virtual serial port),
  // but I do not know yet how to do that from this side.

  SerialPrintStr( EOL "Error servicing the USB connection: " );
  SerialPrintStr( errMsg );
  SerialPrintStr( EOL );

  // We need to consume the data in the Rx buffer, otherwise we may enter an infinite loop.
  s_usbRxBuffer.Reset();

  // There may be little or no place left in the Tx Buffer, but discarding the Tx Buffer
  // at this point does not seem wise.

  // Leave the current mode and enter the console mode. This makes sure
  // that the current mode's termination routine is always called, cleaning up
  // anything that may have been left in a wrong state when the error occurred.
  ChangeBusPirateMode( bpInvalid, nullptr );
  ChangeBusPirateMode( bpConsoleMode, &s_usbTxBuffer );
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
        if ( false )
          SerialPrintStr( "Connection detected, starting the delay timer." EOL );
      }
      break;

    case csInitialDelay:
      if ( !IsUsbConnectionOpen() )
      {
        s_connectionStatus = csNoConnection;
      }
      else if ( HasUptimeElapsedMs( currentTime, s_lastReferenceTimeForUsbOpen, USB_CONNECTION_STABLE_DELAY ) )
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
    HandleError( e.what() );
  }
  catch ( ... )
  {
    HandleError( "Unexpected C++ exception." );
  }
}

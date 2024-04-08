
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


#include "BusPirateConsole.h"  // The include file for this module should come first.

#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/GenericSerialConsole.h>
#include <BareMetalSupport/MainLoopSleep.h>
#include <BareMetalSupport/DebugConsoleEol.h>

#include <stdexcept>
#include <string.h>
#include <inttypes.h>

#include "Globals.h"
#include "BusPirateBinaryMode.h"
#include "BusPirateConnection.h"
#include "UsbConnection.h"
#include "CommandProcessor.h"

#include <udi_cdc.h>


static unsigned s_binaryModeCount;


class CUsbSerialConsole : public CGenericSerialConsole
{
private:
  CUsbTxBuffer * m_txBuffer;

  virtual void Printf ( const char * formatStr, ... ) const override __attribute__ ((format(printf, 2, 3)));

public:

  CUsbSerialConsole ( void )
    : m_txBuffer( nullptr )
  {
    STATIC_ASSERT( MAX_TX_BUFFER_SIZE_NEEDED < USB_TX_BUFFER_SIZE, "Otherwise, there may not be enough space in the tx buffer to complete an operation like backspace." );
  }

  const char * AddSerialChar ( uint8_t c,
                               CUsbTxBuffer * txBuffer,
                               uint32_t * cmdLen );
};


void CUsbSerialConsole::Printf ( const char * const formatStr, ... ) const
{
  assert( m_txBuffer != nullptr );

  va_list argList;
  va_start( argList, formatStr );

  UsbPrintV( m_txBuffer, formatStr, argList );

  va_end( argList );
}


const char * CUsbSerialConsole::AddSerialChar ( const uint8_t c,
                                                CUsbTxBuffer * const txBuffer,
                                                uint32_t * const cmdLen )
{
  const char * ret;

  m_txBuffer = txBuffer;

  try
  {
    ret = AddChar( c, cmdLen );
  }
  catch ( ... )
  {
    m_txBuffer = nullptr;
    throw;
  }

  m_txBuffer = nullptr;

  return ret;
}


class CNativeUsbCommandProcessor : public CCommandProcessor
{
private:
  virtual void Printf ( const char * formatStr, ... ) override __attribute__ ((format(printf, 2, 3)));
  virtual void PrintStr ( const char * str ) override;

public:
    CNativeUsbCommandProcessor ( CUsbRxBuffer * const rxBuffer,
                                 CUsbTxBuffer * const txBuffer )
      : CCommandProcessor( rxBuffer, txBuffer )
  {
  }
};


void CNativeUsbCommandProcessor::Printf ( const char * const formatStr, ... )
{
  assert( m_txBuffer != nullptr );

  va_list argList;
  va_start( argList, formatStr );

  UsbPrintV( m_txBuffer, formatStr, argList );

  va_end( argList );
}


void CNativeUsbCommandProcessor::PrintStr ( const char * const str )
{
  assert( m_txBuffer != nullptr );

  UsbPrintStr( m_txBuffer, str );
}


static CUsbSerialConsole s_console;


static void SpeedTest ( CUsbRxBuffer * const rxBuffer,
                        CUsbTxBuffer * const txBuffer,
                        const uint64_t currentTime )
{
  if ( currentTime >= g_usbSpeedTestEndTime )
  {
    // This message may not make it to the console, depending on the test type.
    UsbPrintStr( txBuffer, EOL "USB speed test finished." EOL );
    UsbPrintStr( txBuffer, BUS_PIRATE_CONSOLE_PROMPT );

    g_usbSpeedTestType = stNone;
    return;
  }


  switch ( g_usbSpeedTestType )
  {
  case stTxSimpleWithTimestamps:
    // Simple loop with the timestamps
    for ( uint32_t i = 0; i < 100; ++i )
    {
      if ( txBuffer->GetFreeCount() < 40 )
        break;

      UsbPrintf( txBuffer, "%" PRIu64 " - %" PRIu64 EOL, currentTime, g_usbSpeedTestEndTime );
    }

    break;

  case stTxSimpleLoop:
   {
    // Simple loop with a dot.
    const uint32_t freeCount = txBuffer->GetFreeCount();

    for ( uint32_t i = 0; i < freeCount; ++i )
      txBuffer->WriteElem( '.' );

    break;
   }

  case stTxFastLoopCircularBuffer:

    // Performance loop with the Circular Buffer, which is the normal way in this firmware.
    // I am getting a throughput of 4.4 MB/s with this method.

    for ( ; ; )
    {
      CUsbTxBuffer::SizeType maxChunkElemCount;
      CUsbTxBuffer::ElemType * const writePtr = txBuffer->GetWritePtr( &maxChunkElemCount );

      if ( maxChunkElemCount == 0 )
        break;

      memset( writePtr, '.', maxChunkElemCount );

      txBuffer->CommitWrittenElements( maxChunkElemCount );
    }

    break;

  case stTxFastLoopRawUsb:
    // This method uses the udi_cdc_write_buf() routine directly.
    // I am getting a throughput of 6.2 MB/s with this method.
    for ( uint32_t i = 0; i < 1000; ++i )
    {
      const uint32_t remainingCount = udi_cdc_write_buf( g_usbSpeedTestBuffer, sizeof( g_usbSpeedTestBuffer ) );

      if ( remainingCount == 0 )
        break;
    }

    // If we do not trigger the main loop iteration manually, we will have idle time between transfers.
    WakeFromMainLoopSleep();
    break;

  case stRxWithCircularBuffer:
   {
    // This test does NOT read the data off the Circular Buffer, it just discards it.
    // I am getting a throughput of 4.5 MB/s with this method.

    const CUsbTxBuffer::SizeType elemCount = rxBuffer->GetElemCount();
    if ( elemCount != 0 )
    {
      if ( false )
      {
        if ( txBuffer->GetFreeCount() >= 80 )
          UsbPrintf( txBuffer, "Discarded %u read bytes." EOL, unsigned(elemCount) );
      }

      rxBuffer->ConsumeReadElements( elemCount );
    }
    break;
   }

  default:
    assert( false );
    break;
  }
}


void BusPirateConsole_ProcessData ( CUsbRxBuffer * const rxBuffer,
                                    CUsbTxBuffer * const txBuffer,
                                    const uint64_t currentTime )
{
  // If we are in speed test mode, and we have not finished testing yet, do nothing else.

  if ( g_usbSpeedTestType != stNone )
  {
    SpeedTest( rxBuffer, txBuffer, currentTime );

    if ( g_usbSpeedTestType != stNone )
      return;
  }


  // Speed is not important here, so we favor simplicity. We only process one command at a time.
  // There is also a limit on the number of bytes consumed, so that the main loop does not get
  // blocked for a long time if we keep getting garbage.

  for ( uint32_t i = 0; i < 100; ++i )
  {
    if ( rxBuffer->IsEmpty() || ! txBuffer->IsEmpty() )
      break;

    const uint8_t byte = rxBuffer->ReadElement();
    bool endLoop = false;

    if ( byte == BIN_MODE_CHAR )
    {
      // For more information about entering binary mode, see here:
      //   http://dangerousprototypes.com/2009/10/09/bus-pirate-raw-bitbang-mode/
      ++s_binaryModeCount;

       if ( s_binaryModeCount == 20 )
       {
         ChangeBusPirateMode( bpBinMode, txBuffer );
         endLoop = true;
       }
    }
    else
    {
      s_binaryModeCount = 0;

      uint32_t cmdLen;
      const char * const cmd = s_console.AddSerialChar( byte, txBuffer, &cmdLen );

      if ( cmd != nullptr )
      {
        UsbPrintStr( txBuffer, EOL );

        CNativeUsbCommandProcessor cmdProcessor( rxBuffer, txBuffer );

        cmdProcessor.ProcessCommand( cmd, currentTime );

        UsbPrintStr( txBuffer, BUS_PIRATE_CONSOLE_PROMPT );

        endLoop = true;
      }
    }

    if ( endLoop )
      break;
  }
}


static void ResetBusPirateConsole ( void )
{
  s_binaryModeCount = 0;
  g_usbSpeedTestType = stNone;
  s_console.Reset();
}


void BusPirateConsole_Init ( CUsbTxBuffer * const txBufferForWelcomeMsg )
{
  ResetBusPirateConsole();

  // Unfortunately, we cannot print here a welcome banner, because OpenOCD will abort when it sees the "Welcome..." text.
  // This may change in the future though, I am planning to submit a patch that would make OpenOCD discard
  // all available input right after establishing the connection.

  if ( false )
  {
    UsbPrintStr( txBufferForWelcomeMsg, "Welcome to the Arduino Due's native USB serial port." EOL );
    UsbPrintStr( txBufferForWelcomeMsg, "Type '?' for help." EOL );
    // Not even a short prompt alone is tolerated:
    UsbPrintStr( txBufferForWelcomeMsg, BUS_PIRATE_CONSOLE_PROMPT );
  }
}


void BusPirateConsole_Terminate ( void )
{
  ResetBusPirateConsole();
}

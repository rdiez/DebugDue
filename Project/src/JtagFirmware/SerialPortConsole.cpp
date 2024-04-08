
// Copyright (C) 2013 R. Diez
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


#include "SerialPortConsole.h"  // The include file for this module should come first.

#include <stdexcept>

#include <BareMetalSupport/GenericSerialConsole.h>
#include <BareMetalSupport/SerialPortAsyncTx.h>
#include <BareMetalSupport/SerialPrint.h>
#include <BareMetalSupport/CircularBuffer.h>
#include <BareMetalSupport/MainLoopSleep.h>
#include <BareMetalSupport/Miscellaneous.h>

#include <uart.h>

#include <Globals.h>

#include "CommandProcessor.h"


#define SERIAL_PORT_RX_BUFFER_SIZE   32

typedef CCircularBuffer< uint8_t, uint32_t, SERIAL_PORT_RX_BUFFER_SIZE > CSerialPortRxBuffer;


// This instance should be "volatile", but then I get difficult compilation errors,
// more investigation is needed. In the mean time, see the AssumeMemoryHasChanged() calls below.
static CSerialPortRxBuffer s_serialPortRxBuffer;


// Note that we do not keep track of the position of these errors. If you need it,
// you will have to store them in the circular buffer next to each received character.
static volatile bool s_uartOverrun = false;
static volatile bool s_uartFrameErr = false;
static volatile bool s_rxBufferOverrun = false;


class CSerialPortConsole : public CGenericSerialConsole
{
private:
  virtual void Printf ( const char * formatStr, ... ) const override __attribute__ ((format(printf, 2, 3)));

public:

  CSerialPortConsole ( void )
  {
  }
};


void CSerialPortConsole::Printf ( const char * formatStr, ... ) const
{
  va_list argList;
  va_start( argList, formatStr );

  SerialPrintV( formatStr, argList );

  va_end( argList );
}


class CProgrammingUsbCommandProcessor : public CCommandProcessor
{
private:
  virtual void Printf ( const char * formatStr, ... ) override __attribute__ ((format(printf, 2, 3)));
  virtual void PrintStr ( const char * str ) override;

public:
    CProgrammingUsbCommandProcessor ( void )
      : CCommandProcessor( nullptr, nullptr )
  {
  }
};


void CProgrammingUsbCommandProcessor::Printf ( const char * const formatStr, ... )
{
  va_list argList;
  va_start( argList, formatStr );

  SerialPrintV( formatStr, argList );

  va_end( argList );
}


void CProgrammingUsbCommandProcessor::PrintStr ( const char * const str )
{
  SerialPrintStr( str );
}


static CSerialPortConsole s_serialPortConsole;


static void ServiceSerialPortRx ( const uint64_t currentTime )
{
  const bool uartOverrun     = s_uartOverrun;
  const bool uartFrameErr    = s_uartFrameErr;
  const bool rxBufferOverrun = s_rxBufferOverrun;

  s_uartOverrun     = false;
  s_uartFrameErr    = false;
  s_rxBufferOverrun = false;

  if ( uartOverrun )
      SerialPrintStr( "UART overrun." EOL );

  if ( uartFrameErr )
      SerialPrintStr( "UART frame error." EOL );

  if ( rxBufferOverrun )
      SerialPrintStr( "UART Rx Buffer overrun." EOL );


  for ( ; ; )
  {
    char c;

    { // Scope for autoDisableInterrupts.
      CAutoDisableInterrupts autoDisableInterrupts;

      AssumeMemoryHasChanged();  // Because s_serialPortRxBuffer should be volatile.

      if ( s_serialPortRxBuffer.IsEmpty() )
        break;

      c = s_serialPortRxBuffer.ReadElement();
    }

    if ( HasSerialPortDataBeenSentSinceLastCall() )
    {
      SerialPrintStr( EOL );
      SerialPrintStr( BUS_PIRATE_CONSOLE_PROMPT );
      s_serialPortConsole.RepaintLine();
    }

    uint32_t cmdLen;
    const char * const cmd = s_serialPortConsole.AddChar( c, &cmdLen );

    if ( cmd != nullptr )
    {
      SerialPrintStr( EOL );

      if ( false )
        SerialPrintf( "Cmd received: %s" EOL, cmd );

      CProgrammingUsbCommandProcessor cmdProcessor;

      cmdProcessor.ProcessCommand( cmd, currentTime );

      SerialPrintStr( BUS_PIRATE_CONSOLE_PROMPT );
    }

    HasSerialPortDataBeenSentSinceLastCall();  // Reset the flag.
  }
}


static void HandleError ( const char * const errMsg )
{
  SerialPrintStr( EOL "Error servicing the serial port connection: " );
  SerialPrintStr( errMsg );
  SerialPrintStr( EOL );
}


void ServiceSerialPortConsole ( const uint64_t currentTime )
{
  try
  {
    ServiceSerialPortRx( currentTime );
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


static void SerialPortRxInterruptHandler ( void )
{
  // There is no FIFO in our UART, so we process just 1 character every time this interrupt is triggered.

  // POSSIBLE OPTIMISATION: Use the DMA channels to transfer data.

  const uint32_t status = UART->UART_SR;

  if ( status & UART_SR_RXRDY )
  {
    // We must always read the available character, otherwise the interrupt will trigger again.
    const char c = char( UART->UART_RHR );

    { // Scope for autoDisableInterrupts.

      CAutoDisableInterrupts autoDisableInterrupts;

      AssumeMemoryHasChanged();  // Because s_serialPortRxBuffer should be volatile.

      if ( s_serialPortRxBuffer.IsFull() )
      {
        s_rxBufferOverrun = true;
      }
      else
      {
        s_serialPortRxBuffer.WriteElem( c );
      }

    }  // Scope for autoDisableInterrupts.

    WakeFromMainLoopSleep();
  }

  if ( status & UART_SR_OVRE )
  {
    s_uartOverrun = true;
  }

  if ( status & UART_SR_FRAME )
  {
    s_uartFrameErr = true;
  }

  if ( status & ( UART_SR_OVRE | UART_SR_FRAME ) )
  {
    UART->UART_CR |= UART_CR_RSTSTA;
    WakeFromMainLoopSleep();
  }
}


void UART_Handler ( void )
{
  SerialPortRxInterruptHandler();
  SerialPortAsyncTxInterruptHandler();
}

void InitSerialPortConsole ( void )
{
    HasSerialPortDataBeenSentSinceLastCall();  // Reset the flag.
}

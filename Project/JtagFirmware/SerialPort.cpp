
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


#include "SerialPort.h"  // The include file for this module should come first.

#include <stdexcept>

#include <BareMetalSupport/SerialConsole.h>
#include <BareMetalSupport/DebugConsole.h>
#include <BareMetalSupport/CircularBuffer.h>
#include <BareMetalSupport/MainLoopSleep.h>
#include <BareMetalSupport/Miscellaneous.h>

#include <uart.h>

#include <Globals.h>

#define SERIAL_PORT_RX_BUFFER_SIZE  32

typedef CCircularBuffer< uint8_t, uint32_t, SERIAL_PORT_RX_BUFFER_SIZE > CSerialPortRxBuffer;


// This instance should be "volatile", but then I get difficult compilation errors,
// more investigation is needed. In the mean time, see AssumeMemoryHasChanged() below.

static CSerialPortRxBuffer s_serialPortRxBuffer;

inline void AssumeMemoryHasChanged ( void )
{
  // This routine tries to compensate for the lack of 'volatile' in s_serialPortRxBuffer.

  asm volatile( "" ::: "memory" );
}


// Note that we do not keep track of the position of these errors. If you need it,
// you will have to store them in the circular buffer next to each received character.
static volatile bool s_uartOverrun = false;
static volatile bool s_uartFrameErr = false;
static volatile bool s_rxBufferOverrun = false;


class CSerialPortConsole : public CSerialConsole
{
private:
  virtual void Printf ( const char * formatStr, ... ) __attribute__ ((format(printf, 2, 3)));

public:

  CSerialPortConsole ( void )
  {
  }
};


void CSerialPortConsole::Printf ( const char * formatStr, ... )
{
  va_list argList;
  va_start( argList, formatStr );

  DbgconPrintV( formatStr, argList );

  va_end( argList );
}


static CSerialPortConsole s_serialPortConsole;


static void WritePrompt ( void )
{
  DbgconPrintStr( ">" );
}


void ServiceSerialPort ( void )
{
  const bool uartOverrun     = s_uartOverrun;
  const bool uartFrameErr    = s_uartFrameErr;
  const bool rxBufferOverrun = s_rxBufferOverrun;

  s_uartOverrun     = false;
  s_uartFrameErr    = false;
  s_rxBufferOverrun = false;

  if ( uartOverrun )
      DbgconPrintStr( "UART overrun." EOL );
    
  if ( uartFrameErr )
      DbgconPrintStr( "UART frame error." EOL );

  if ( rxBufferOverrun )
      DbgconPrintStr( "UART Rx Buffer overrun." EOL );
  

  for ( ; ; )
  {
    char c;

    { // Scope for autoDisableInterrupts.
      CAutoDisableInterrupts autoDisableInterrupts;

      AssumeMemoryHasChanged();

      if ( s_serialPortRxBuffer.IsEmpty() )
        break;

      c = s_serialPortRxBuffer.ReadElement();
    }

    uint32_t cmdLen;
    const char * const cmd = s_serialPortConsole.AddChar( c, &cmdLen );

    if ( cmd != NULL )
    {
      DbgconPrintStr( EOL );

      try
      {
        if ( true ) // TODO: set to false.
          DbgconPrint( "Cmd received: %s" EOL, cmd );

        // ParseCommand( cmd, rxBuffer, txBuffer, currentTime );
      }
      catch ( const std::exception & e )
      {
        DbgconPrint( "Error processing command: %s" EOL, e.what() );
      }

      
      WritePrompt();
    }
  }
}


void UART_Handler ( void )
{
  // There is no FIFO in our UART, so we process just 1 character every time this interrupt is triggered.

  // POSSIBLE OPTIMISATION: Use the DMA channels to transfer data.

  const uint32_t status = UART->UART_SR;

  if ( status & UART_SR_RXRDY )
  {
    if ( false )
      DbgconPrintStr( "Serial port character received." EOL );

    // We must always read the available character, otherwise the interrupt will trigger again.
    const char c = UART->UART_RHR;

    { // Scope for autoDisableInterrupts.
      CAutoDisableInterrupts autoDisableInterrupts;

      AssumeMemoryHasChanged();

      if ( s_serialPortRxBuffer.IsFull() )
      {
        s_rxBufferOverrun = true;
      }
      else
      {
        s_serialPortRxBuffer.WriteElem( c );
      }
    }

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

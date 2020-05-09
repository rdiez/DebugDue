
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


#include "SerialPortAsyncTx.h"  // The include file for this module should come first.

#include <assert.h>
#include <string.h>

#include "AssertionUtils.h"
#include "Miscellaneous.h"
#include "CircularBuffer.h"

#include <BoardSupport-ArduinoDue/DebugConsoleSupport.h>

#include <sam3xa.h>
#include <uart.h>


static const unsigned MAX_EOL_LEN = 2;
static const char * s_eol = nullptr;


void InitSerialPortAsyncTx ( const char * const eol )
{
  assert( WasSerialPortInitialised() );

  assert( eol != nullptr );
  assert( s_eol == nullptr );

  assert( strlen(eol) > 0 );
  assert( strlen(eol) <= MAX_EOL_LEN );

  s_eol = eol;
}


#ifndef NDEBUG
static bool HasBeenInitialised ( void ) throw()
{
  return s_eol != nullptr;
}
#endif


const char * GetSerialPortEol ( void ) throw()
{
  assert( HasBeenInitialised() );
  return s_eol;
}


volatile bool s_hasDataBeenSentSinceLastCall;

// This routine is not watertight, as the flag is not reliable.
// Serial port data may come at any point anyway.
// This routine is designed to try and make the user experience more confortable when using
// a console that can also print data asynchronously from background tasks.
// Most times, it will work, at other times the keyboard input will get mixed with other output,
// just like in the standard shell consoles.

bool HasSerialPortDataBeenSentSinceLastCall ( void ) throw()
{
  const bool ret = s_hasDataBeenSentSinceLastCall;

  s_hasDataBeenSentSinceLastCall = false;

  return ret;
}


#define SERIAL_PORT_TX_BUFFER_SIZE 4096

// If the buffer overflows, the user will get a warning message. Wait until the buffer is
// half empty before restarting normal behaviour, otherwise the user may get many
// such messages in a row.
#define OVERFLOW_REARM_THRESHOLD ( SERIAL_PORT_TX_BUFFER_SIZE / 2 )


typedef CCircularBuffer< char, uint32_t, SERIAL_PORT_TX_BUFFER_SIZE > CSerialPortTxBuffer;

// This instance should be "volatile", but then I get difficult compilation errors,
// more investigation is needed. In the mean time, see AssumeMemoryHasChanged() below.
static CSerialPortTxBuffer s_serialPortTxBuffer;

static const char OVERFLOW_MSG[] = "[Some output is missing here due to serial port Tx buffer overflow]";
static const size_t OVERFLOW_MSG_LEN = sizeof(OVERFLOW_MSG) - 1;

static volatile bool s_txBufferOverflowMode = false;


#ifndef NDEBUG
static bool IsTxReadyInterruptEnabled ( void )
{
  const bool isNvicInterruptEnabled = 0 != ( NVIC->ISER[ ((uint32_t)( UART_IRQn ) >> 5) ] & ( 1 << UART_IRQn ) );
  const bool isTxReadyInterruptEnabled = 0 != ( UART->UART_IMR & UART_IMR_TXRDY );
  return isNvicInterruptEnabled && isTxReadyInterruptEnabled;
}
#endif


void SendSerialPortAsyncData ( const char * data, const size_t dataLen )
{
  // WARNING: This routine blocks interrupts for some time.
  // WARNING: This routine may be called in interrupt context.

  // POSSIBLE OPTIMISATION: The CPU has a DMA unit that can be used to speed-up UART tranfers.

  assert( HasBeenInitialised() );

  if ( dataLen == 0 )
  {
    // This could happen, but is unusual.
    assert( false );
    return;
  }

  s_hasDataBeenSentSinceLastCall = true;

  { // Scope for autoDisableInterrupts.

    // Note that interrupts can be disabled for a long time here. If that could be
    // a problem, you can write a loop below in order to transfer small data chunks
    // at a time, and enable interrupts between those transfers.

    CAutoDisableInterrupts autoDisableInterrupts;

    if ( s_txBufferOverflowMode )
      return;

    AssumeMemoryHasChanged();  // Because s_serialPortTxBuffer should be volatile.

    const uint32_t freeCount = s_serialPortTxBuffer.GetFreeCount();
    size_t dataLenToUse;

    if ( dataLen <= freeCount )
    {
      dataLenToUse = dataLen;
    }
    else
    {
      dataLenToUse = freeCount;

      s_txBufferOverflowMode = true;

      if ( dataLenToUse == 0 )
        return;
    }


    // Note that the "Tx ready" interrupt should only be enabled if and only if
    // there was unsent data left in the Tx Buffer, see the asserts below.
    const bool wasEmpty = s_serialPortTxBuffer.IsEmpty();

    s_serialPortTxBuffer.WriteElemArray( data, dataLenToUse );

    // Trying to send the first byte straight away is an optimisation that might not
    // always be desirable. For a start, it means that SerialPortAsyncTxInterruptHandler()
    // must block interrupts when looking at UART->UART_SR.
    const bool TRY_TO_SEND_FIRST_BYTE_NOW = true;

    if ( TRY_TO_SEND_FIRST_BYTE_NOW )
    {
      // We can send the first byte now if:
      // 1) The Tx buffer did not already have unsent data.
      //    Sending should happen later, when the "Tx ready" interrupt comes.
      // 2) The Tx data register is empty. The Tx buffer may be empty,
      //    but the last byte sent may still be waiting in the UART.

      if ( wasEmpty )
      {
        assert( !IsTxReadyInterruptEnabled() );

        const uint32_t status = UART->UART_SR;

        if ( status & UART_SR_TXRDY )
        {
          UART->UART_THR = s_serialPortTxBuffer.ReadElement();

          // If there is still more data to send, arm the "Tx ready" interrupt.
          if ( !s_serialPortTxBuffer.IsEmpty() )
            uart_enable_interrupt( UART, UART_IER_TXRDY );
        }
        else
        {
          uart_enable_interrupt( UART, UART_IER_TXRDY );
        }
      }
      else
      {
        assert( IsTxReadyInterruptEnabled() );
      }
    }
    else
    {
      uart_enable_interrupt( UART, UART_IER_TXRDY );
    }
  } // Scope for autoDisableInterrupts.
}


void SerialPortAsyncTxInterruptHandler ( void ) throw()
{
  // WARNING: This routine is always called in interrupt context.

  CAutoDisableInterrupts autoDisableInterrupts;

  AssumeMemoryHasChanged();  // Because s_serialPortTxBuffer should be volatile.

  // There is no separate "Tx ready" interrupt. When the serial port interrupt triggers,
  // we have no way to know whether it was "Tx ready", "Rx ready", both at the same time
  // or something else. Therefore, we have to check here whether we still have something to send.
  //
  // We could also check IsTxReadyInterruptEnabled(), which would have the same effect,
  // as the "Tx ready" interrupt should only be enabled if there still is data left
  // in the Tx Buffer.
  //
  // This check should be performed first, as the most common scenario is that the
  // Tx data register is empty and there is no data to send.

  if ( s_serialPortTxBuffer.IsEmpty() )
  {
    assert( !IsTxReadyInterruptEnabled() );
    return;
  }

  assert( IsTxReadyInterruptEnabled() );


  // Note that we must disable interrupts before reading UART->UART_SR,
  // in case feature TRY_TO_SEND_FIRST_BYTE_NOW is enabled.

  const uint32_t status = UART->UART_SR;

  if ( 0 == ( status & UART_SR_TXRDY ) )
    return;

  const uint8_t c = s_serialPortTxBuffer.ReadElement();

  if ( s_serialPortTxBuffer.IsEmpty() )
  {
    uart_disable_interrupt( UART, UART_IDR_TXRDY );
  }

  UART->UART_THR = c;

  if ( s_txBufferOverflowMode && s_serialPortTxBuffer.GetFreeCount() >= OVERFLOW_REARM_THRESHOLD )
  {
    STATIC_ASSERT( OVERFLOW_REARM_THRESHOLD > OVERFLOW_MSG_LEN + 2 * MAX_EOL_LEN, "The threshold is too low." );

    const size_t eolLen = strlen( s_eol );
    s_serialPortTxBuffer.WriteElemArray( s_eol, eolLen );
    s_serialPortTxBuffer.WriteElemArray( OVERFLOW_MSG, OVERFLOW_MSG_LEN );
    s_serialPortTxBuffer.WriteElemArray( s_eol, eolLen );
    s_txBufferOverflowMode = false;
  }
}

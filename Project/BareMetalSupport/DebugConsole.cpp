
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


#include "DebugConsole.h"  // The include file for this module should come first.

#include <assert.h>
#include <string.h>

#include "Miscellaneous.h"
#include "IntegerPrintUtils.h"
#include "AssertionUtils.h"

#include <sam3xa.h>
#include <pmc.h>


static bool s_isSerialPortInitialised = false;


void InitDebugConsole ( void )
{
  assert( !s_isSerialPortInitialised );
  s_isSerialPortInitialised = true;

  VERIFY( 0 == pmc_enable_periph_clk( ID_UART ) );

  // Disable PDC channel
  UART->UART_PTCR = UART_PTCR_RXTDIS | UART_PTCR_TXTDIS;

  // Reset and disable receiver and transmitter
  UART->UART_CR = UART_CR_RSTRX | UART_CR_RSTTX | UART_CR_RXDIS | UART_CR_TXDIS;

  // Configure mode
  UART->UART_MR = UART_MR_PAR_NO | UART_MR_CHMODE_NORMAL;

  // Configure baudrate (asynchronous, no oversampling)
  UART->UART_BRGR = (SystemCoreClock / 115200) >> 4;

  // Configure interrupts.
  // We don't need these interrupts at the moment:
  //   UART->UART_IDR = 0xFFFFFFFF;
  //   UART->UART_IER = UART_IER_RXRDY | UART_IER_OVRE | UART_IER_FRAME;
  //
  // Enable UART interrupt in NVIC
  // NVIC_EnableIRQ( UART_IRQn );

  // Enable receiver and transmitter
  UART->UART_CR = UART_CR_RXEN | UART_CR_TXEN ;
}


static void WaitForTxReady ( void )
{
  while ( (UART->UART_SR & UART_SR_TXRDY) != UART_SR_TXRDY )
  {
  }
}


void DbgconWaitForDataSent ( void )
{
  while ( (UART->UART_SR & UART_SR_TXEMPTY) != UART_SR_TXEMPTY )
  {
  }
}


static void WriteSerialPortCharSync ( const uint8_t uc_data )
{
  assert( s_isSerialPortInitialised );

  WaitForTxReady();

  UART->UART_THR = uc_data;
}


void DbgconSyncWriteStr ( const char * const msg )
{
  for ( const char * p = msg; *p != '\0'; ++p )
    WriteSerialPortCharSync( *p );
}


void DbgconSyncWriteUint32Hex ( const uint32_t val )
{
  char hexBuffer[CONVERT_UINT32_TO_HEX_BUFSIZE];
  ConvertUint32ToHex( val, hexBuffer, false );
  DbgconSyncWriteStr( hexBuffer );
}


void DbgconPrintStr ( const char * const msg )
{
  DbgconSyncWriteStr( msg );
}


// It is hard to keep the last discarded characters, and there is often an end-of-line sequence there.
// As a (cheap) work-around, insert always an LF.
static const char TRUNCATION_SUFFIX[] = "[...]" LF;

void DbgconPrintV ( const char * const formatStr, va_list argList )
{
  const size_t TRUNCATION_SUFFIX_LEN = sizeof( TRUNCATION_SUFFIX ) - 1;

  char buffer[ MAX_DBGCON_PRINT_LEN + TRUNCATION_SUFFIX_LEN + 1 ];

  const int len = vsnprintf( buffer, MAX_DBGCON_PRINT_LEN + 1, formatStr, argList );

  // If the string was truncated, append the truncation suffix.
  // Leave the last 3 characters in place, so that any end-of-line characters remain.

  if ( len >= MAX_DBGCON_PRINT_LEN + 1 )
  {
    assert( false );  // We should not need to truncate any lines.

    assert( buffer[ MAX_DBGCON_PRINT_LEN ] == 0 );
    memcpy( &buffer[ MAX_DBGCON_PRINT_LEN ], TRUNCATION_SUFFIX, TRUNCATION_SUFFIX_LEN + 1 );
    assert( strlen(buffer) == MAX_DBGCON_PRINT_LEN + TRUNCATION_SUFFIX_LEN );
  }

  DbgconPrintStr( buffer );
}


void DbgconPrint ( const char * formatStr, ... )
{
  va_list argList;
  va_start( argList, formatStr );

  DbgconPrintV( formatStr, argList );

  va_end( argList );
}


// This routine could be improved in many ways:
// - Make it faster by building a complete line and sending it at once.
// - Provide memory addresses and/or offsets on the left.
// - Provide an ASCII dump on the right.
// - Use different data sizes (8 bits, 16 bits, 32 bits).

void DbgconHexDump ( const void * const ptr,
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
      DbgconPrintStr( endOfLineChars );
    }
    const uint8_t b = bytePtr[ i ];
    DbgconPrint( "0x%02X ", b );
    ++lineElemCount;
  }

  DbgconPrintStr( endOfLineChars );
}


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


#include "SerialPortUtils.h"  // The include file for this module should come first.

#include <assert.h>

#include "Miscellaneous.h"
#include "IntegerPrintUtils.h"
#include "AssertionUtils.h"

#include <sam3xa.h>
#include <pmc.h>
#include <uart.h>


static bool s_isSerialPortInitialised = false;

bool WasSerialPortInitialised ( void )
{
  return s_isSerialPortInitialised;
}


void InitSerialPort ( const bool enableRxInterrupt )
{
  assert( !WasSerialPortInitialised() );
  s_isSerialPortInitialised = true;

  VERIFY( 0 == pmc_enable_periph_clk( ID_UART ) );

  // Disable PDC channel
  UART->UART_PTCR = UART_PTCR_RXTDIS | UART_PTCR_TXTDIS;

  // Reset and disable receiver and transmitter
  UART->UART_CR = UART_CR_RSTRX | UART_CR_RSTTX | UART_CR_RXDIS | UART_CR_TXDIS;

  // Configure mode
  UART->UART_MR = UART_MR_PAR_NO | UART_MR_CHMODE_NORMAL;

  // Configure baudrate (asynchronous, no oversampling)
  UART->UART_BRGR = (CPU_CLOCK / 115200) >> 4;

  if ( enableRxInterrupt )
  {
    uart_disable_interrupt( UART, 0xFFFFFFFF );  // Disable all interrupts, we will enable only selected ones below.
    uart_enable_interrupt( UART, UART_IER_RXRDY | UART_IER_OVRE | UART_IER_FRAME );
    NVIC_EnableIRQ( UART_IRQn );
  }

  // Enable receiver and transmitter.
  uart_enable_tx( UART );
  uart_enable_rx( UART );
}


static void WaitForTxReady ( void )
{
  while ( (UART->UART_SR & UART_SR_TXRDY) != UART_SR_TXRDY )
  {
  }
}


void SerialWaitForDataSent ( void )
{
  while ( (UART->UART_SR & UART_SR_TXEMPTY) != UART_SR_TXEMPTY )
  {
  }
}


static void WriteSerialPortCharSync ( const uint8_t uc_data )
{
  assert( WasSerialPortInitialised() );

  WaitForTxReady();

  UART->UART_THR = uc_data;
}


void SerialSyncWriteStr ( const char * const msg )
{
  for ( const char * p = msg; *p != '\0'; ++p )
    WriteSerialPortCharSync( *p );
}


void SerialSyncWriteUint32Hex ( const uint32_t val )
{
  char hexBuffer[CONVERT_UINT32_TO_HEX_BUFSIZE];
  ConvertUint32ToHex( val, hexBuffer, false );
  SerialSyncWriteStr( hexBuffer );
}




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


#include "DebugConsoleSupport.h"  // The include file for this module should come first.

#include <BareMetalSupport/DebugConsoleSerialSync.h>

#include <Misc/AssertionUtils.h>

#include <sam3xa.h>
#include <pmc.h>
#include <uart.h>


static bool s_isSerialPortInitialised = false;

bool WasSerialPortInitialised ( void ) throw()
{
  return s_isSerialPortInitialised;
}


void InitSerialPort ( const bool enableRxInterrupt ) throw()
{
  assert( !WasSerialPortInitialised() );
  s_isSerialPortInitialised = true;

  VERIFY( 0 == pmc_enable_periph_clk( ID_UART ) );

  // Disable any receive and transmit transfers on the UART channel of the Peripheral DMA Controller (PDC).
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


static void WaitForTxReady ( void ) throw()
{
  while ( (UART->UART_SR & UART_SR_TXRDY) != UART_SR_TXRDY )
  {
  }
}


void SerialWaitForDataSent ( void ) throw()
{
  while ( (UART->UART_SR & UART_SR_TXEMPTY) != UART_SR_TXEMPTY )
  {
  }
}


void WriteSerialPortCharSync ( const uint8_t c ) throw()
{
  assert( WasSerialPortInitialised() );

  WaitForTxReady();

  UART->UART_THR = c;
}


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


// Include this header file only once.
#ifndef USB_BUFFERS_H_INCLUDED
#define USB_BUFFERS_H_INCLUDED

#include <BareMetalSupport/CircularBuffer.h>

// The way we handle the USB reception and transmission buffers is a compromise
// between memory usage and speed. After all, we have a slow embedded processor
// with very little RAM.
//
// Every time one or several bytes of data are received, they are placed into the reception buffer
// and routine BusPirateConnection_ProcessData() gets called. This routine may consume received data,
// or decide that a command is not yet complete and do not consume any data.
//
// With the current implementation, commands can only be processed when they are complete,
// therefore the reception buffer must be big enough to accomodate the largest possible command.
// Note that, if there is enough place left and the transmitter sent more than one command at once,
// part of the next command may already be available in the reception buffer.
//
// When a command is complete, its received data gets consumed, and optionally a response is generated
// in the transmission buffer. Again, this buffer must be big enough for the longest possible reply.
// The transmission buffer is mostly filled in place, in order to avoid copying the data around.
//
// With the current implementation, the next received command cannot be processed until
// the transmission buffer has enough room left for its response. This means that, if the previous
// reponse has not been transmitted yet, processing of the next command may be delayed.
//
// Routine BusPirateConnection_ProcessData() gets also called a periodic intervals, so that it can
// time-out a command whenever necessary.

#define OPEN_OCD_CMD_CODE_LEN  1

#define MAX_JTAG_TAP_SHIFT_BIT_COUNT  (uint32_t(8192))  // This depends on the original Bus Pirate implementation,
                                                        // and it is the value hard-coded in OpenOCD.
#define MAX_JTAG_TAP_SHIFT_BYTE_COUNT (uint32_t( (MAX_JTAG_TAP_SHIFT_BIT_COUNT + 7) / 8 ) )
#define TAP_SHIFT_CMD_HEADER_LEN      (uint32_t( OPEN_OCD_CMD_CODE_LEN + 2 ))

// These buffers can hold the biggest possible command and its reponse, although commands are normally
// much smaller than the maximum size.
#define USB_TX_BUFFER_SIZE uint32_t( TAP_SHIFT_CMD_HEADER_LEN + MAX_JTAG_TAP_SHIFT_BYTE_COUNT )
#define USB_RX_BUFFER_SIZE uint32_t( TAP_SHIFT_CMD_HEADER_LEN + MAX_JTAG_TAP_SHIFT_BYTE_COUNT * 2 )

typedef CCircularBuffer< uint8_t, uint32_t, USB_TX_BUFFER_SIZE > CUsbTxBuffer;
typedef CCircularBuffer< uint8_t, uint32_t, USB_RX_BUFFER_SIZE > CUsbRxBuffer;

#define MAX_USB_PRINT_LEN 256
void UsbPrint ( CUsbTxBuffer * txBuffer, const char * formatStr, ... ) __attribute__ ((format(printf, 2, 3)));


#endif  // Include this header file only once.

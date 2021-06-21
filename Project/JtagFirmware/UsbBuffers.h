
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

#pragma once

#include <stdarg.h>

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
// in the transmission buffer. Again, this buffer must be big enough for the longest possible reply,
// especially when processing binary mode commands. When performance matters, the transmission buffer
// is mostly filled in place, in order to avoid copying the data around.
//
// With the current implementation, the next received command cannot be processed until
// the transmission buffer has enough room left for its response. This means that, if the previous
// reponse has not been transmitted yet, processing of the next command may be delayed.
//
// Routine BusPirateConnection_ProcessData() gets also called a periodic intervals, so that it can
// time-out a command whenever necessary.
//
// The current circular buffer is a generic implementation that should work on other platforms
// or environments where data is transmitted perhaps over different interfaces.
// The Atmel Software Framework library uses its own buffers, probably the same USB hardware buffers
// that the ATSAM3X8 has. It may be possible to optimise the code to use these hardware buffers directly
// so that it does not need the extra circular buffers any more. However, such an
// optimised implementation would probably be tied to the USB buffer architecture of that
// particular Atmel chip's. I do not have enough experience to tell whether that architecture
// is also popular across the USB chip industry.

// These buffers can hold the biggest possible command and its reponse, although commands are normally
// much smaller than the maximum size.
#define USB_RX_BUFFER_SIZE 4096  // This size matches the buffer size used in OpenOCD's routine buspirate_tap_execute(),
                                 // but it is probably never used to its maximum capacity.
#define USB_TX_BUFFER_SIZE 4096  // The Tx Buffer must accomodate the largest possible command reply.
                                 // The biggest OpenOCD command is CMD_TAP_SHIFT, which needs twice as much
                                 // Rx Buffer as Tx Buffer. Another source of large data in a single block
                                 // is the text of the 'help' console command.

typedef CCircularBuffer< uint8_t, uint32_t, USB_TX_BUFFER_SIZE > CUsbTxBuffer;
typedef CCircularBuffer< uint8_t, uint32_t, USB_RX_BUFFER_SIZE > CUsbRxBuffer;

// The maximum print length below determines how much stack space routine UsbPrintf() needs.
#define MAX_USB_PRINT_LEN 256
void UsbPrintf ( CUsbTxBuffer * txBuffer, const char * formatStr, ... ) __attribute__ ((format(printf, 2, 3)));
void UsbPrintV ( CUsbTxBuffer * const txBuffer, const char * const formatStr, va_list argList ) __attribute__ ((format(printf, 2, 0)));

void UsbPrintChar ( CUsbTxBuffer * txBuffer, const char c );
void UsbPrintStr ( CUsbTxBuffer * txBuffer, const char * str );

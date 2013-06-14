// Include this header file only once.
#ifndef BMS_SERIAL_PORT_ASYNC_TX_H_INCLUDED
#define BMS_SERIAL_PORT_ASYNC_TX_H_INCLUDED

// This module stores outgoing data in a Tx circular buffer,
// and then sends the data asynchronously (interrupt driven) over the serial port.
//
// Note that the user must manually call routine SerialPortAsyncTxInterruptHandler()
// from his serial port interrupt handler.
//
// If the Tx buffer overflows, all excess data is discarded. When further data is sent
// over the serial port and the Tx buffer has room again, the user gets a warning message
// and then normal operation is resumed.
//
// Routine SendSerialPortAsyncData() can also be called from interrupt context,
// so that tracing to the serial console is safe from any context.

#include <stdint.h>
#include <stddef.h>  // For size_t.


void InitSerialPortAsyncTx ( const char * eol );

void SerialPortAsyncTxInterruptHandler ( void );

void SendSerialPortAsyncData ( const char * data, size_t dataLen );

const char * GetSerialPortEol ( void );

bool HasSerialPortDataBeenSentSinceLastCall ( void );


#endif  // Include this header file only once.

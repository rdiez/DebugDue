// Include this header file only once.
#ifndef BMS_SERIAL_PORT_UTILS_H_INCLUDED
#define BMS_SERIAL_PORT_UTILS_H_INCLUDED

#include <stdint.h>


void InitSerialPort ( bool enableRxInterrupt );

bool WasSerialPortInitialised ( void );


// If you use the following routines, you should not use the "Serial Port Tx Buffer" ones simultaneously.

void SerialSyncWriteStr ( const char * msg );
void SerialSyncWriteUint32Hex ( uint32_t val );
void SerialWaitForDataSent ( void );


#endif  // Include this header file only once.

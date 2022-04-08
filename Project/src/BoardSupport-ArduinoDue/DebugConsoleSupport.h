
#pragma  once

#include <stdint.h>


void InitSerialPort ( bool enableRxInterrupt ) throw();

bool WasSerialPortInitialised ( void ) throw();

void SerialWaitForDataSent ( void ) throw();

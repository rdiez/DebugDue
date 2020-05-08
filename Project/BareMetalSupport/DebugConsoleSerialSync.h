
#pragma once

#include <stdint.h>


// If you use the following routines, you should not use the "Serial Port Tx Buffer" ones simultaneously.

void WriteSerialPortCharSync ( uint8_t c ) throw();
void SerialSyncWriteStr ( const char * msg ) throw();
void SerialSyncWriteUint32Hex ( uint32_t val ) throw();

// Include this header file only once.
#ifndef BUS_PIRATE_BINARY_MODE_H_INCLUDED
#define BUS_PIRATE_BINARY_MODE_H_INCLUDED

#include "UsbBuffers.h"

#define BIN_MODE_CHAR  (uint8_t( 0x00 ))
#define OOCD_MODE_CHAR (uint8_t( 0x06 ))

void BusPirateBinaryMode_Init ( CUsbTxBuffer * txBuffer );
void BusPirateBinaryMode_Terminate ( void );
void BusPirateBinaryMode_ProcessData ( CUsbRxBuffer * rxBuffer, CUsbTxBuffer * txBuffer );


#endif  // Include this header file only once.

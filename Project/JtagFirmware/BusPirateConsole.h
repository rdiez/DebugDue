// Include this header file only once.
#ifndef BUS_PIRATE_CONSOLE_H_INCLUDED
#define BUS_PIRATE_CONSOLE_H_INCLUDED

#include "UsbBuffers.h"

void BusPirateConsole_Init ( CUsbTxBuffer * txBufferForWelcomeMsg );
void BusPirateConsole_ProcessData ( CUsbRxBuffer * rxBuffer, CUsbTxBuffer * txBuffer, uint64_t currentTime );
void BusPirateConsole_Terminate ( void );


#endif  // Include this header file only once.

// Include this header file only once.
#ifndef BUS_PIRATE_CONNECTION_H_INCLUDED
#define BUS_PIRATE_CONNECTION_H_INCLUDED

#include "UsbBuffers.h"

void BusPirateConnection_Init        ( CUsbTxBuffer * txBuffer );
void BusPirateConnection_ProcessData ( CUsbRxBuffer * rxBuffer, CUsbTxBuffer * txBuffer, uint64_t currentTime );
void BusPirateConnection_Terminate   ( void );


enum BusPirateModeEnum
{
  bpInvalid = 0,
  bpConsoleMode,
  bpBinMode,
  bpOpenOcdMode
};

void ChangeBusPirateMode ( BusPirateModeEnum newMode, CUsbTxBuffer * txBufferForWelcomeMsg );


#endif  // Include this header file only once.

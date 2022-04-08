#pragma once

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

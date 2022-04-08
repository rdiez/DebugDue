#pragma once

#include "UsbBuffers.h"

void BusPirateConsole_Init ( CUsbTxBuffer * txBufferForWelcomeMsg );
void BusPirateConsole_ProcessData ( CUsbRxBuffer * rxBuffer, CUsbTxBuffer * txBuffer, uint64_t currentTime );
void BusPirateConsole_Terminate ( void );

// Include this header file only once.
#ifndef BUS_PIRATE_OPENOCD_MODE_H_INCLUDED
#define BUS_PIRATE_OPENOCD_MODE_H_INCLUDED

#include "UsbBuffers.h"

void InitJtagPins ( void );

void BusPirateOpenOcdMode_Init ( CUsbTxBuffer * txBuffer );
void BusPirateOpenOcdMode_Terminate ( void );

void BusPirateOpenOcdMode_ProcessData ( CUsbRxBuffer * rxBuffer, CUsbTxBuffer * txBuffer );


// The following routines are only used from outside for test purposes.

void PrintJtagPinStatus ( CUsbTxBuffer * txBuffer );

void ShiftJtagData ( CUsbRxBuffer * rxBuffer,
                     CUsbTxBuffer * txBuffer,
                     uint16_t dataBitCount );

enum JtagPinModeEnum
{
    // These values are specified in the Bus Pirate <-> OpenOCD protocol.
    MODE_HIZ     = 0,
    MODE_JTAG    = 1,  // Normal mode.
    MODE_JTAG_OD = 2,  // Open-drain outputs.
};


JtagPinModeEnum GetJtagPinMode ( void );
void SetJtagPinMode ( JtagPinModeEnum mode );

void SetJtagPullups ( bool enablePullUps );
bool GetJtagPullups ( void );


#endif  // Include this header file only once.

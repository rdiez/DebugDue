#pragma once

#include "UsbBuffers.h"

#include <BareMetalSupport/IoUtils.h>


#define BUS_PIRATE_CONSOLE_PROMPT ">"

enum UsbSpeedTestEnum
{
  stNone,
  stTxSimpleWithTimestamps,
  stTxSimpleLoop,
  stTxFastLoopCircularBuffer,
  stTxFastLoopRawUsb,
  stRxWithCircularBuffer
};

extern uint8_t g_usbSpeedTestBuffer[ 1000 ];
extern uint64_t g_usbSpeedTestEndTime;
extern UsbSpeedTestEnum g_usbSpeedTestType;


class CCommandProcessor
{
private:
  bool m_simulateProcolError;

  void ParseCommand ( const char * cmdBegin, uint64_t currentTime );
  void HexDump ( const void * ptr, size_t byteCount, const char * endOfLineChars );
  void PrintMemory ( const char * paramBegin );
  void BusyWait ( const char * paramBegin );
  void ProcessUsbSpeedTestCmd ( const char * paramBegin, uint64_t currentTime );
  void DisplayResetCause ( void );
  void DisplayCpuLoad ( void );
  void SimulateError ( const char * paramBegin );
  void PrintJtagPinStatus ( void );
  void PrintPinStatus ( const char * const pinName,
                        const Pio * const pioPtr,
                        const uint8_t pinNumber  // 0-31
                      );
protected:

  // These 2 buffers are only non-NULL when processing commands from the Arduino Due's 'Native' USB connection.
  // When connected over the serial port to the 'Programming' connection, they are both NULL.
  CUsbRxBuffer * const m_rxBuffer;
  CUsbTxBuffer * const m_txBuffer;

  virtual void Printf ( const char * formatStr, ... ) __attribute__ ((format(printf, 2, 3))) = 0;
  virtual void PrintStr ( const char * str ) = 0;

  bool IsNativeUsbPort ( void ) const;

public:

  CCommandProcessor ( CUsbRxBuffer * const rxBuffer,
                      CUsbTxBuffer * const txBuffer )
    : m_rxBuffer( rxBuffer )
    , m_txBuffer( txBuffer )
  {
  }

  void ProcessCommand ( const char * cmdStr,
                        uint64_t currentTime );
};

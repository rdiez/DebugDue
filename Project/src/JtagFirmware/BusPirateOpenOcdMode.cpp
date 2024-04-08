
// Copyright (C) 2012 R. Diez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the Affero GNU General Public License version 3
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// Affero GNU General Public License version 3 for more details.
//
// You should have received a copy of the Affero GNU General Public License version 3
// along with this program. If not, see http://www.gnu.org/licenses/ .


#include "BusPirateOpenOcdMode.h"  // The include file for this module should come first.

#include <assert.h>
#include <stdexcept>
#include <inttypes.h>

#include <BareMetalSupport/SerialPrint.h>
#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/IoUtils.h>
#include <Misc/AssertionUtils.h>

#include "BusPirateConnection.h"
#include "BusPirateBinaryMode.h"
#include "Globals.h"
#include "JtagPins.h"


#define OPEN_OCD_CMD_CODE_LEN         1
#define TAP_SHIFT_CMD_HEADER_LEN      ( uint32_t( OPEN_OCD_CMD_CODE_LEN + 2 ) )
#define MAX_JTAG_TAP_SHIFT_BIT_COUNT  ( ( USB_RX_BUFFER_SIZE - TAP_SHIFT_CMD_HEADER_LEN ) / 2 * 8 )


#ifndef NDEBUG
  static bool s_wasInitialised = false;
#endif


// Below are some performance settings you can tweak, they choose different implementations.
// I would keep even the slowest implementations, as they can serve as examples
// or test case helpers when writing  new FPGA or assembly code.
// The current settings yield the maximum performance with GCC 4.7.3, -O3.
// Command "JtagShiftSpeedTest" displays a speed of 267 KiB/s.

// You would think that FULL_BYTE_IMPLEMENTATION should always be faster, but it is not,
// at least with GCC 4.7.3 . If you disable USE_BLOCKS below, you will get a faster
// performance with this option also turned off.
static const bool FULL_BYTE_IMPLEMENTATION = false;

// This option only has an effect if FULL_BYTE_IMPLEMENTATION is enabled.
// The loop implementation in Shift2Bits() ends up being faster, at least with GCC 4.7.3 .
static const bool SHIFT_2_BITS_LOOP_IMPLEMENTATION = true;

static const bool SHIFT_USE_BLOCKS = true;


// This flag allows you to check whether the TDO value read stays constant for some time.
// If that's not the case, the firmware is probably reading TDO too soon after TCK's falling edge.
// This kind of test does not help if the JTAG TAP switches TDO to a high impedance on those
// TAP state machine states that do not deliver any data, as required by the JTAG standard.
// That is, this TDO test only works for non-conformant JTAG TAPs, like is often the case
// with FPGA-based implementations.
//
// A value of 0 below means this kind of test is disabled (the default).
//
// Note that, if you set the iteration value too high, you will delay the JTAG shifts and
// you may then trigger OpenOCD time-outs.
//
// This variable could be unsigned, but then you get a compilation warning when it's 0.
static const int32_t TDO_STABILITY_TEST_LOOP_COUNT = 0;

static const bool TRACE_JTAG_SHIFTING = false;


#define FIRST_PARAM_POS OPEN_OCD_CMD_CODE_LEN

// #define CMD_UNKNOWN    0x00 -  See BIN_MODE_CHAR instead.
#define CMD_PORT_MODE     0x01
#define CMD_FEATURE       0x02
#define CMD_READ_ADCS     0x03
//#define CMD_TAP_SHIFT   0x04 // Old protocol, no longer used.
#define CMD_TAP_SHIFT     0x05
// #define CMD_ENTER_OOCD 0x06 -  See OOCD_MODE_CHAR instead.
#define CMD_UART_SPEED    0x07
#define CMD_JTAG_SPEED    0x08

enum
{
    SERIAL_NORMAL = 0,
    SERIAL_FAST   = 1
};

enum
{
    FEATURE_LED    = 0x01,
    FEATURE_VREG   = 0x02,
    FEATURE_TRST   = 0x04,
    FEATURE_SRST   = 0x08,
    FEATURE_PULLUP = 0x10
};


enum
{
    ACTION_DISABLE = 0,
    ACTION_ENABLE  = 1
};


static JtagPinModeEnum s_pinMode;
static bool s_pullUps;


static void ConfigureJtagPins ( void )
{
  // SerialPrintStr( "Configuring the JTAG pins..." EOL );

  assert( IsPinControlledByPio( JTAG_TDI_PIO , JTAG_TDI_PIN  ) );
  assert( IsPinControlledByPio( JTAG_TMS_PIO , JTAG_TMS_PIN  ) );
  assert( IsPinControlledByPio( JTAG_TDO_PIO , JTAG_TDO_PIN  ) );
  assert( IsPinControlledByPio( JTAG_TCK_PIO , JTAG_TCK_PIN  ) );

  assert( IsPinControlledByPio( JTAG_TRST_PIO, JTAG_TRST_PIN ) );
  assert( IsPinControlledByPio( JTAG_SRST_PIO, JTAG_SRST_PIN ) );

  assert( IsPinControlledByPio( JTAG_VCC_PIO , JTAG_VCC_PIN  ) );
  assert( IsPinControlledByPio( JTAG_GND1_PIO, JTAG_GND1_PIN ) );
  assert( IsPinControlledByPio( JTAG_GND2_PIO, JTAG_GND2_PIN ) );

  // VCC and GND.
  pio_set_input( JTAG_VCC_PIO , BV(JTAG_VCC_PIN ), 0 );
  pio_set_input( JTAG_GND1_PIO, BV(JTAG_GND1_PIN), 0 );
  pio_set_input( JTAG_GND2_PIO, BV(JTAG_GND2_PIN), 0 );


  // JTAG outputs.
  // On the Bus Pirate, the pull-up option affects only MOSI (TDI), MISO (TDO), CLK (TCK) and CS(TMS),
  // as only those 4 signals are connected to the CD4066B analog switch.

  bool configureOutputsAsInputs;

  switch ( GetJtagPinMode() )
  {
  default:
    assert( false );
    // Fall through.

  case MODE_HIZ:
    configureOutputsAsInputs = true;
    break;

  case MODE_JTAG:
  case MODE_JTAG_OD:
    configureOutputsAsInputs = false;
    break;
  }

  // The pull-up setting only affects these 4 JTAG signals, like in the Bus Pirate: TDI, TDO, TCK and TMS.

  const uint32_t inputPullUpOption  = s_pullUps ? PIO_PULLUP : 0;
  const uint32_t outputPullUpOption = s_pullUps ? ENABLE     : DISABLE;

  if ( configureOutputsAsInputs )
  {
    pio_set_input( JTAG_TMS_PIO , BV(JTAG_TMS_PIN) , inputPullUpOption );
    pio_set_input( JTAG_TCK_PIO , BV(JTAG_TCK_PIN) , inputPullUpOption );
    pio_set_input( JTAG_TDI_PIO , BV(JTAG_TDI_PIN) , inputPullUpOption );

    pio_set_input( JTAG_TRST_PIO, BV(JTAG_TRST_PIN), 0 );
    pio_set_input( JTAG_SRST_PIO, BV(JTAG_SRST_PIN), 0 );
  }
  else
  {
    const uint32_t outputOpenDrain = GetJtagPinMode() == MODE_JTAG_OD ? ENABLE : DISABLE;

    pio_set_output( JTAG_TMS_PIO , BV(JTAG_TMS_PIN) , HIGH, outputOpenDrain, outputPullUpOption );
    pio_set_output( JTAG_TCK_PIO , BV(JTAG_TCK_PIN) , HIGH, outputOpenDrain, outputPullUpOption );
    pio_set_output( JTAG_TDI_PIO , BV(JTAG_TDI_PIN) , HIGH, outputOpenDrain, outputPullUpOption );

    pio_set_output( JTAG_TRST_PIO, BV(JTAG_TRST_PIN), HIGH, outputOpenDrain, 0 );
    pio_set_output( JTAG_SRST_PIO, BV(JTAG_SRST_PIN), HIGH, outputOpenDrain, 0 );
  }

  // JTAG input (TDO).
  pio_set_input( JTAG_TDO_PIO, BV(JTAG_TDO_PIN), inputPullUpOption );


  // SerialPrintStr( "Finished configuring the JTAG pins." EOL );
}


void InitJtagPins ( void )
{
  s_pinMode = MODE_HIZ;
  s_pullUps = false;
  ConfigureJtagPins();
}


void SetJtagPinMode ( const JtagPinModeEnum mode )
{
  switch ( mode )
  {
  case MODE_HIZ:
    // SerialPrintStr( "Mode: HiZ." EOL );
    break;

  case MODE_JTAG:
    // SerialPrintStr( "Mode: JTAG normal." EOL );
    break;

  case MODE_JTAG_OD:
    // SerialPrintStr( "Mode: JTAG open-drain." EOL );
    break;

  default:
    throw std::runtime_error( "Invalid mode in CMD_PORT_MODE." );
  }

  s_pinMode = mode;
  ConfigureJtagPins();
}


JtagPinModeEnum GetJtagPinMode ( void )
{
  return s_pinMode;
}


void SetJtagPullups ( const bool enablePullUps )
{
  s_pullUps = enablePullUps;

  ConfigureJtagPins();
}

bool GetJtagPullups ( void )
{
  return s_pullUps;
}


static void HandleFeature ( const uint8_t feature, const uint8_t action )
{
  if ( action != ACTION_ENABLE &&
       action != ACTION_DISABLE )
  {
    throw std::runtime_error( "Invalid action in in CMD_FEATURE." );
  }

  switch ( feature )
  {
  case FEATURE_LED:
    // We use the Arduino Due's LED as a kind of visual heartbeat.
    // OpenOCD never sends this command by default, so ignore it.
    // The user can manually send this command though, so maybe in the future
    // we want to support it.
    //   SetLed( action == ACTION_ENABLE );
    break;

  case FEATURE_VREG:
    // We don't have a voltage regulator that could supply an external circuit,
    // so ignore this command.

    // if ( action == ACTION_ENABLE )
    //   SerialPrintStr( "Feature: Voltage Regulator on." EOL );
    // else
    //   SerialPrintStr( "Feature: Voltage Regulator off." EOL );

    break;

  case FEATURE_PULLUP:
    // if ( action == ACTION_ENABLE )
    //   SerialPrintStr( "Feature: Pull-up resistors on." EOL );
    // else
    //   SerialPrintStr( "Feature: Pull-up resistors off." EOL );

    SetJtagPullups( action == ACTION_ENABLE );

    break;

  case FEATURE_TRST:
    if ( false )
    {
      if ( action == ACTION_ENABLE )
        SerialPrintStr( "Feature: TRST on." EOL );
      else
        SerialPrintStr( "Feature: TRST off." EOL );
    }

    SetOutputDataDrivenOnPin( JTAG_TRST_PIO, JTAG_TRST_PIN, action == ACTION_ENABLE );

    break;

  case FEATURE_SRST:
    // We have not defined an SRST pin yet in our JTAG interface.
    if ( false )
    {
      if ( action == ACTION_ENABLE )
        SerialPrintStr( "Feature: SRST on." EOL );
      else
        SerialPrintStr( "Feature: SRST off." EOL );
    }

    SetOutputDataDrivenOnPin( JTAG_SRST_PIO, JTAG_SRST_PIN, action == ACTION_ENABLE );

    break;

  default:
    throw std::runtime_error( "Unknown feature in CMD_FEATURE." );
  }
}


static void SendOpenOcdModeWelcome ( CUsbTxBuffer * const txBuffer )
{
  UsbPrintStr( txBuffer, "OCD1" );
}


static bool PeekCmdData ( CUsbRxBuffer * const rxBuffer, uint8_t * cmdData, const uint32_t cmdDataSize )
{
  if ( rxBuffer->GetElemCount() < cmdDataSize )
    return false;

  rxBuffer->PeekMultipleElements( cmdDataSize, cmdData );

  return true;
}


static bool ShiftSingleBit ( const bool tdiBit, const bool tmsBit )
{
  // I have measured TCK once with the oscilloscope and, with GCC 4.7.3 and optimisation level "-O3",
  // I got around 3.04 MHz (in 8-bit bursts), and around 4.88 us (204-222 KHz) between 8-bit bursts,
  // as there is a longer pause between the 8-bit bursts.
  // All these measurements were rather inaccurate.
  // The main limiting factor will probably be the short time between the TCK's falling edge and
  // the reading of TDO.
  //
  // Unfortunately, the SPI interface on Atmel's ATSAM3X8 is not flexible enough to help
  // drive the JTAG signals (we would need an extra line CPU -> JTAG slave). The USART interfaces
  // don't have enough flexibility and speed either, so we have to toggle the pins manually
  // for maximum performance.


  assert( GetOutputDataDrivenOnPin( JTAG_TCK_PIO, JTAG_TCK_PIN ) );
  SetOutputDataDrivenOnPinToLow( JTAG_TCK_PIO, JTAG_TCK_PIN );

  SetOutputDataDrivenOnPin( JTAG_TDI_PIO, JTAG_TDI_PIN, tdiBit );
  SetOutputDataDrivenOnPin( JTAG_TMS_PIO, JTAG_TMS_PIN, tmsBit );

  SetOutputDataDrivenOnPinToHigh( JTAG_TCK_PIO, JTAG_TCK_PIN );

  // The new TDO value appears on the line after TCK's falling edge. Therefore, at this point
  // we are reading the TDO value left behind by the last shift operation, that is,
  // by the previous call to this routine.
  // Or maybe the current TAP state does not deliver any data, the TDO is in high-impedance mode,
  // and the data read back is rubbish anyway and will be thrown away.
  const bool isTdoSet = IsInputPinHigh( JTAG_TDO_PIO, JTAG_TDO_PIN );

  // This loop does not normally run, see TDO_STABILITY_TEST_LOOP_COUNT
  // for more information about this test.
  for ( int32_t i = 0; i < TDO_STABILITY_TEST_LOOP_COUNT; ++i )
  {
    if ( isTdoSet != IsInputPinHigh( JTAG_TDO_PIO, JTAG_TDO_PIN ) )
    {
      SerialPrintf( "TDO stability check failed at iteration %" PRId32 "." EOL, i );
      assert( false );
      break;
    }
  }

  return isTdoSet;
}


static uint8_t ShiftSeveralBits ( const uint8_t tdi8,
                                  const uint8_t tms8,
                                  const uint8_t bitCount )
{
  assert( bitCount > 0 && bitCount <= 8 );

  uint8_t shiftingTdi8 = tdi8;
  uint8_t shiftingTms8 = tms8;
  uint8_t tdo8 = 0;

  for ( unsigned j = 0; j < bitCount; ++j )
  {
    // LSB goes out first.
    const bool tdiBit = 0 != ( shiftingTdi8 & 1 );
    const bool tmsBit = 0 != ( shiftingTms8 & 1 );

    shiftingTdi8 >>= 1;
    shiftingTms8 >>= 1;

    const bool isTdoSet = ShiftSingleBit( tdiBit, tmsBit );

    // MSB comes in first.
    tdo8 = (tdo8 >> 1) | uint8_t( isTdoSet ? (1<<7) : 0 );
  }

  if ( TRACE_JTAG_SHIFTING )
    SerialPrintf( "TDI8: 0x%02X, TMS8: 0x%02X, TDO8: 0x%02X" EOL, tdi8, tms8, tdo8 );


  // Note that OpenOCD 0.8.0's Bus Pirate driver does not bother clearing the last buffer
  // contents before sending a new one, so, if the bit count is not a multiple of 8,
  // the last TDI and TMS bits may not be zero, they may be rubbish from the data previously sent.
  // However, I have changed my OpenOCD locally to clear those bits, I intend to submit a patch soon.
  if ( true )
  {
    assert( shiftingTdi8 == 0 );
    assert( shiftingTms8 == 0 );
  }

  return tdo8;
}


static uint8_t Shift2BitsHelper ( uint8_t tdiMsb, uint8_t tdiLsb,
                                  uint8_t tmsMsb, uint8_t tmsLsb )
{
  const bool lsb = ShiftSingleBit( tdiLsb, tmsLsb );
  const bool msb = ShiftSingleBit( tdiMsb, tmsMsb );

  if ( lsb )
  {
    if ( msb )
      return 3;
    else
      return 1;
  }
  else
  {
    if ( msb )
      return 2;
    else
      return 0;
  }
}


static uint8_t Shift2Bits ( uint8_t tdi8,
                            uint8_t tms8 )
{
  if ( SHIFT_2_BITS_LOOP_IMPLEMENTATION )
  {
    uint8_t byteToSend = 0;

    for ( unsigned j = 0; j < 2; ++j )
    {
      // LSB goes out first.
      const bool tdiBit = 0 != ( tdi8 & 1 );
      const bool tmsBit = 0 != ( tms8 & 1 );

      tdi8 >>= 1;
      tms8 >>= 1;

      const bool isTdoSet = ShiftSingleBit( tdiBit, tmsBit );

      // MSB comes in first.
      byteToSend = (byteToSend >> 1) | uint8_t( isTdoSet ? (1<<1) : 0 );
    }

    return byteToSend;
  }
  else if ( false )
  {
    // This is an alternative implementation which does not get optimised properly by GCC 4.7.3 .
    switch ( tdi8 & 3 )
    {
    case 0:
     {
      const bool tdiMsb = false;
      const bool tdiLsb = false;

      switch ( tms8 & 3 )
      {
      case 0: return Shift2BitsHelper( tdiMsb, tdiLsb, false, false );
      case 1: return Shift2BitsHelper( tdiMsb, tdiLsb, false, true  );
      case 2: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  false );
      case 3: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  true  );
      default:
        assert( false );
        return 0;
      }
      break;
     }

    case 1:
     {
      const bool tdiMsb = false;
      const bool tdiLsb = true;

      switch ( tms8 & 3 )
      {
      case 0: return Shift2BitsHelper( tdiMsb, tdiLsb, false, false );
      case 1: return Shift2BitsHelper( tdiMsb, tdiLsb, false, true  );
      case 2: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  false );
      case 3: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  true  );
      default:
        assert( false );
        return 0;
      }
      break;
     }

    case 2:
     {
      const bool tdiMsb = true;
      const bool tdiLsb = false;

      switch ( tms8 & 3 )
      {
      case 0: return Shift2BitsHelper( tdiMsb, tdiLsb, false, false );
      case 1: return Shift2BitsHelper( tdiMsb, tdiLsb, false, true  );
      case 2: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  false );
      case 3: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  true  );
      default:
        assert( false );
        return 0;
      }
      break;
     }

    case 3:
     {
      const bool tdiMsb = true;
      const bool tdiLsb = true;

      switch ( tms8 & 3 )
      {
      case 0: return Shift2BitsHelper( tdiMsb, tdiLsb, false, false );
      case 1: return Shift2BitsHelper( tdiMsb, tdiLsb, false, true  );
      case 2: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  false );
      case 3: return Shift2BitsHelper( tdiMsb, tdiLsb, true,  true  );
      default:
        assert( false );
        return 0;
      }
      break;
     }

    default:
      assert( false );
      return 0;
    }
  }
  else
  {
    switch ( (tdi8 & 3) << 2 | (tms8 & 3) )
    {
    case 0b0000:
      return Shift2BitsHelper( false, false, false, false );
    case 0b0001:
      return Shift2BitsHelper( false, false, false, true  );
    case 0b0010:
      return Shift2BitsHelper( false, false, true , false );
    case 0b0011:
      return Shift2BitsHelper( false, false, true , true  );
    case 0b0100:
      return Shift2BitsHelper( false, true , false, false );
    case 0b0101:
      return Shift2BitsHelper( false, true , false, true  );
    case 0b0110:
      return Shift2BitsHelper( false, true , true , false );
    case 0b0111:
      return Shift2BitsHelper( false, true , true , true  );
    case 0b1000:
      return Shift2BitsHelper( true , false, false, false );
    case 0b1001:
      return Shift2BitsHelper( true , false, false, true  );
    case 0b1010:
      return Shift2BitsHelper( true , false, true , false );
    case 0b1011:
      return Shift2BitsHelper( true , false, true , true  );
    case 0b1100:
      return Shift2BitsHelper( true , true , false, false );
    case 0b1101:
      return Shift2BitsHelper( true , true , false, true  );
    case 0b1110:
      return Shift2BitsHelper( true , true , true , false );
    case 0b1111:
      return Shift2BitsHelper( true , true , true , true  );

    default:
      assert( false );
      return 0;
    }
  }
}


static uint8_t ShiftFullByte ( const uint8_t tdi8,
                               const uint8_t tms8 )
{
  // SerialPrint( "TDI8: 0x%02X" EOL, tdi8 );
  // SerialPrint( "TMS8: 0x%02X" EOL, tms8 );

  const uint8_t tdo1 = Shift2Bits( tdi8,      tms8 );
  const uint8_t tdo2 = Shift2Bits( tdi8 >> 2, tms8 >> 2 );
  const uint8_t tdo3 = Shift2Bits( tdi8 >> 4, tms8 >> 4 );
  const uint8_t tdo4 = Shift2Bits( tdi8 >> 6, tms8 >> 6 );

  const uint8_t tdo = uint8_t( tdo4 << 6 ) |
                      uint8_t( tdo3 << 4 ) |
                      uint8_t( tdo2 << 2 ) |
                               tdo1;
  return tdo;
}


static void ShiftJtagData_OneBufferByteAtATime ( CUsbRxBuffer * const rxBuffer,
                                                 CUsbTxBuffer * const txBuffer,
                                                 const uint16_t fullDataByteCount )
{
  for ( unsigned i = 0; i < fullDataByteCount; ++i )
  {
    const uint8_t tdi8 = rxBuffer->ReadElement();
    const uint8_t tms8 = rxBuffer->ReadElement();

    uint8_t tdo8;

    if ( FULL_BYTE_IMPLEMENTATION )
      tdo8 = ShiftFullByte( tdi8, tms8 );
    else
      tdo8 = ShiftSeveralBits( tdi8, tms8, 8 );

    txBuffer->WriteElem( tdo8 );
  }
}


static void ShiftMemBlock ( const uint8_t * const __restrict__ readPtr,
                                  uint8_t * const __restrict__ writePtr,
                            const uint16_t iterationCount )
{
  for ( uint32_t i = 0; i < iterationCount; ++i )
  {
    const uint8_t tdi8 = readPtr[ i*2     ];
    const uint8_t tms8 = readPtr[ i*2 + 1 ];

    uint8_t tdo8;

    if ( FULL_BYTE_IMPLEMENTATION )
      tdo8 = ShiftFullByte( tdi8, tms8 );
    else
      tdo8 = ShiftSeveralBits( tdi8, tms8, 8 );

    writePtr[i] = tdo8;
  }
}


static void ShiftJtagData_InBufferBlocks ( CUsbRxBuffer * const rxBuffer,
                                           CUsbTxBuffer * const txBuffer,
                                           const uint16_t fullDataByteCount )
{
  uint16_t remainingBytes = fullDataByteCount;

  while ( remainingBytes > 0 )
  {
    uint32_t maxReadCount;
    uint32_t maxWriteCount;

    const uint8_t * const readPtr  = rxBuffer->GetReadPtr ( &maxReadCount );
          uint8_t * const writePtr = txBuffer->GetWritePtr( &maxWriteCount );

    assert( maxReadCount  > 0 );
    assert( maxWriteCount > 0 );

    // We need to read 2 bytes for each byte we write, because we output 2 bits (TDI and TMS)
    // for each TDO bit we sample in.

    const uint16_t maxIterationCount = uint16_t( MinFrom( MinFrom( maxReadCount / 2, maxWriteCount ), uint32_t( remainingBytes ) ) );

    // SerialPrint( "It cnt: %u" EOL, unsigned( maxIterationCount ) );

    if ( maxIterationCount == 0 )
    {
      assert( maxReadCount == 1 );

      ShiftJtagData_OneBufferByteAtATime( rxBuffer, txBuffer, 1 );
      --remainingBytes;

      continue;
    }

    ShiftMemBlock( readPtr, writePtr, maxIterationCount );

    rxBuffer->ConsumeReadElements( maxIterationCount * 2 );
    txBuffer->CommitWrittenElements( maxIterationCount );

    remainingBytes -= maxIterationCount;
  }
}


void ShiftJtagData ( CUsbRxBuffer * const rxBuffer,
                     CUsbTxBuffer * const txBuffer,
                     const uint16_t dataBitCount )
{
  if ( TRACE_JTAG_SHIFTING )
    SerialPrintf( "--- Begin of JTAG shifting for %" PRIu16 " bits ---" EOL, dataBitCount );

  const uint16_t fullDataByteCount = dataBitCount / 8;
  const uint8_t  restBitCount      = uint8_t( dataBitCount % 8 );

  // This loop could be optimised as follows:
  // 1) The fastest code would probably be hand-written assembly.
  //    It would also be the best way to make sure that the timing is right,
  //    because the C implementation tends to generate uneven TCK periods.
  // 2) Maybe move the port pins so that we can set TCK, TDI and TMS pins in a single operation.
  //    I am not sure whether that would improve performance much.
  // 3) We might gain some speed by reading the data as aligned 32-bit words as much as possible.


  if ( SHIFT_USE_BLOCKS )
  {
    // In one of the tests, I have seen around 88 KB/sec with GDB "load" command.
    ShiftJtagData_InBufferBlocks( rxBuffer, txBuffer, fullDataByteCount );
  }
  else
  {
    // In the same test as above, I have seen around 81 KB/sec with GDB "load" command.
    ShiftJtagData_OneBufferByteAtATime( rxBuffer, txBuffer, fullDataByteCount );
  }


  if ( restBitCount > 0 )
  {
    const uint8_t tdi8 = rxBuffer->ReadElement();
    const uint8_t tms8 = rxBuffer->ReadElement();

    const uint8_t tdo8 = ShiftSeveralBits( tdi8, tms8, restBitCount );

    txBuffer->WriteElem( tdo8 );
  }

  if ( TRACE_JTAG_SHIFTING )
    SerialPrintStr( "--- End of JTAG shifting ---" EOL );
}


static bool ShiftCommand ( CUsbRxBuffer * const rxBuffer,
                           CUsbTxBuffer * const txBuffer )
{
  uint8_t cmdHeader[ TAP_SHIFT_CMD_HEADER_LEN ];

  if ( !PeekCmdData( rxBuffer, cmdHeader, sizeof(cmdHeader) ) )
    return false;

  const uint8_t len1 = cmdHeader[ FIRST_PARAM_POS + 0 ];
  const uint8_t len2 = cmdHeader[ FIRST_PARAM_POS + 1 ];

  const uint16_t dataBitCount = uint16_t( len1 << 8 | len2 );

  // A command with more data bits than MAX_JTAG_TAP_SHIFT_BIT_COUNT will never fit
  // in the Rx Buffer, so we would be waiting forever for the command to be complete.

  if ( dataBitCount > MAX_JTAG_TAP_SHIFT_BIT_COUNT )
  {
    // The Bus Pirate firmware has a hard-coded limit of 0x2000.
    STATIC_ASSERT( MAX_JTAG_TAP_SHIFT_BIT_COUNT >= 0x2000, "We should support at least the Bus Pirate's maximum limit." );

    throw std::runtime_error( "CMD_TAP_SHIFT data len too big." );
  }


  const unsigned dataByteCount = unsigned( ( dataBitCount + 7 ) / 8 );
  const uint32_t cmdLen   = TAP_SHIFT_CMD_HEADER_LEN + dataByteCount * 2;
  const uint32_t replyLen = TAP_SHIFT_CMD_HEADER_LEN + dataByteCount;

  if ( rxBuffer->GetElemCount() < cmdLen   ||
       txBuffer->GetFreeCount() < replyLen )
  {
    return false;
  }

  rxBuffer->ConsumeReadElements( TAP_SHIFT_CMD_HEADER_LEN );

  // SerialPrint( "CMD_TAP_SHIFT: %u bits." EOL, dataBitCount );

  STATIC_ASSERT( TAP_SHIFT_CMD_HEADER_LEN == 3, "Header size mismatch" );
  txBuffer->WriteElem( CMD_TAP_SHIFT );
  txBuffer->WriteElem( len1 );
  txBuffer->WriteElem( len2 );

  ShiftJtagData( rxBuffer, txBuffer, dataBitCount );

  return true;
}


static bool ProcessReceivedData ( CUsbRxBuffer * const rxBuffer,
                                  CUsbTxBuffer * const txBuffer )
{
  if ( rxBuffer->IsEmpty() )
    return false;

  bool callMeAgain = false;

  const uint8_t cmdCode = *rxBuffer->PeekElement();

  switch ( cmdCode )
  {
  case BIN_MODE_CHAR:
    if ( txBuffer->IsEmpty() )
    {
      rxBuffer->ConsumeReadElements( OPEN_OCD_CMD_CODE_LEN );
      ChangeBusPirateMode( bpBinMode, txBuffer );
      assert( !callMeAgain );
    }
    break;

  case OOCD_MODE_CHAR:
    // We are already in OpenOCD mode, just print the welcome message again.
    if ( txBuffer->IsEmpty() )
    {
      rxBuffer->ConsumeReadElements( OPEN_OCD_CMD_CODE_LEN );
      SendOpenOcdModeWelcome( txBuffer );
      callMeAgain = true;
    }
    break;

  case CMD_READ_ADCS:
    throw std::runtime_error( "CMD_READ_ADCS not supported yet." );

  case CMD_JTAG_SPEED:
    throw std::runtime_error( "CMD_JTAG_SPEED not supported yet." );

  case CMD_PORT_MODE:
    {
      uint8_t cmdData[OPEN_OCD_CMD_CODE_LEN+1];

      if ( PeekCmdData( rxBuffer, cmdData, sizeof(cmdData) ) )
      {
        // SerialPrintStr( "CMD_PORT_MODE." EOL );
        SetJtagPinMode( JtagPinModeEnum( cmdData[ FIRST_PARAM_POS ] ) );

        rxBuffer->ConsumeReadElements( sizeof( cmdData ) );
        callMeAgain = true;
      }
    }
    break;

  case CMD_FEATURE:
    {
      uint8_t cmdData[OPEN_OCD_CMD_CODE_LEN+2];

      if ( PeekCmdData( rxBuffer, cmdData, sizeof(cmdData) ) )
      {
        // SerialPrintStr( "CMD_FEATURE." EOL );
        HandleFeature( cmdData[ FIRST_PARAM_POS + 0 ],
                       cmdData[ FIRST_PARAM_POS + 1 ] );

        rxBuffer->ConsumeReadElements( sizeof( cmdData ) );
        callMeAgain = true;
      }
    }
    break;

  case CMD_UART_SPEED:
    {
      uint8_t cmdData[OPEN_OCD_CMD_CODE_LEN+3];
      const uint32_t RESPONSE_SIZE = 2;

      if ( txBuffer->GetFreeCount() >= RESPONSE_SIZE &&
           PeekCmdData( rxBuffer, cmdData, sizeof(cmdData) ) )
      {
        // SerialPrintStr( "CMD_UART_SPEED." EOL );

        // Any attempts to change the serial port speed for this USB connection are just ignored.
        const uint8_t serialSpeed = cmdData[ FIRST_PARAM_POS + 0 ];

        assert( serialSpeed == SERIAL_NORMAL ||
                serialSpeed == SERIAL_FAST );
        assert( cmdData[ FIRST_PARAM_POS + 1 ] == 0xAA );
        assert( cmdData[ FIRST_PARAM_POS + 2 ] == 0x55 );

        STATIC_ASSERT( RESPONSE_SIZE == 2, "Internal error" );
        txBuffer->WriteElem( CMD_UART_SPEED );
        txBuffer->WriteElem( serialSpeed );

        rxBuffer->ConsumeReadElements( sizeof( cmdData ) );
        callMeAgain = true;
      }
    }
    break;

  case CMD_TAP_SHIFT:
    callMeAgain = ShiftCommand( rxBuffer, txBuffer );
    break;

  default:
    if ( txBuffer->GetFreeCount() >= 1 )
    {
      SerialPrintf( "Unknown OpenOCD command with code %" PRIu8 " (0x%02" PRIX8 ").", cmdCode, cmdCode );
      assert( false );  // This should actually never happen if the client is written correctly.

      // Answer with a single zero. The protocol does not allow for any better error indication.
      // Alternative, we could throw here, which resets the whole connection.
      txBuffer->WriteElem( 0 );

      rxBuffer->ConsumeReadElements( 1 );  // We can only guess here how long the command is.

      // Something is not right, allow the main loop to trigger again, this increases the chances
      // that the error reply above gets sent quickly. If we are reading rubbish, it does not matter
      // that it takes a little longer to read it all.
      assert( !callMeAgain );
    }

    break;
  }

  return callMeAgain;
}


void BusPirateOpenOcdMode_ProcessData ( CUsbRxBuffer * const rxBuffer, CUsbTxBuffer * const txBuffer )
{
  assert( s_wasInitialised );

  // Speed is important here, and the receive buffer is not so big, so process all we can here.
  // In order to prevent starving the main loop, there is a limit on the number of commands
  // that can be executed at once.

  // We should allow in debug builds at least one main loop iteration every MAINLOOP_WAKE_UP_CPU_LOAD_MS.
  const unsigned MAX_CMD_COUNT = 20;

  for ( unsigned i = 0; i < MAX_CMD_COUNT; ++i )
  {
    const bool repeatIteration = ProcessReceivedData( rxBuffer, txBuffer );

    if ( !repeatIteration )
      break;
  }
}


void BusPirateOpenOcdMode_Init ( CUsbTxBuffer * const txBuffer )
{
  assert( !s_wasInitialised );

  #ifndef NDEBUG
    s_wasInitialised = true;
  #endif

  // Note that routine InitJtagPins() has already been called at start-up time.

  // There is an error-handling path that might get us here with a non-empty Tx Buffer.
  SendOpenOcdModeWelcome( txBuffer );
}

void BusPirateOpenOcdMode_Terminate ( void )
{
  assert( s_wasInitialised );

  InitJtagPins();

  #ifndef NDEBUG
   s_wasInitialised = false;
  #endif
}

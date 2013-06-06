
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

#include <BareMetalSupport/DebugConsole.h>
#include <BareMetalSupport/AssertionUtils.h>
#include <BareMetalSupport/Miscellaneous.h>
#include <BareMetalSupport/IoUtils.h>

#include "BusPirateConnection.h"
#include "BusPirateBinaryMode.h"
#include "Globals.h"


#define OPEN_OCD_CMD_CODE_LEN         1
#define TAP_SHIFT_CMD_HEADER_LEN      ( uint32_t( OPEN_OCD_CMD_CODE_LEN + 2 ) )
#define MAX_JTAG_TAP_SHIFT_BIT_COUNT  ( uint32_t( ( USB_RX_BUFFER_SIZE - TAP_SHIFT_CMD_HEADER_LEN ) / 2 * 8  ) )


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

// JTAG pins, 10-pin connector.
// This is the same layout as the Altera USB Blaster connector with Atmel AVR's additions:
// Legend: Arduino Pin number (printed on the board) / Port pin / USB Blaster Pin number
//   42/PA19/09 TDI | 43/PA20/10 GND2
//   44/PC19/07  -  | 45/PC18/08 nTRST
//   46/PC17/05 TMS | 47/PC16/06 nSRST
//   48/PC15/03 TDO | 49/PC14/04 VCC
//   50/PC13/01 TCK | 51/PC12/02 GND1
// Note that there is a console command to list these pins.
// None of the Arduino Due pins selected above has any other alternate function (like SPI bus)
// listed on the Arduino source code (hardware/arduino/sam/variants/arduino_due_x/variant.cpp).
//
// Older pinout I used, it was too close to the 5V pins at the edge.
// Legend: Arduino Pin number / Chip pin number / Port pin number
//   31/26/PA07 TDI | 30/22/PD09 GND1
//   29/19/PD06  -  | 28/16/PD03  -
//   27/15/PD02 TMS | 26/14/PD01  -
//   25/13/PD00 TDO | 24/08/PA15 VCC
//   23/07/PA14 TCK | 22/01/PB26 GND2


// JTAG data signals.

#define JTAG_TDI_PIO  PIOA
#define JTAG_TDI_PIN  19

#define JTAG_TMS_PIO  PIOC
#define JTAG_TMS_PIN  17

#define JTAG_TDO_PIO  PIOC
#define JTAG_TDO_PIN  15

#define JTAG_TCK_PIO  PIOC
#define JTAG_TCK_PIN  13


// JTAG reset signals.

#define JTAG_TRST_PIO  PIOC
#define JTAG_TRST_PIN  18

#define JTAG_SRST_PIO  PIOC
#define JTAG_SRST_PIN  16


// JTAG voltage signals.

#define JTAG_VCC_PIO  PIOC
#define JTAG_VCC_PIN  14

#define JTAG_GND1_PIO  PIOC
#define JTAG_GND1_PIN  12

#define JTAG_GND2_PIO  PIOA
#define JTAG_GND2_PIN  20


static void ConfigureJtagPins ( void )
{
  // DbgconPrintStr( "Configuring the JTAG pins..." EOL );

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


  // DbgconPrintStr( "Finished configuring the JTAG pins." EOL );
}


void InitJtagPins ( void )
{
  s_pinMode = MODE_HIZ;
  s_pullUps = false;
  ConfigureJtagPins();
}


static void PrintPinStatus ( CUsbTxBuffer * const txBuffer,
                             const char * const pinName,
                             const Pio * const pioPtr,
                             const uint8_t pinNumber  // 0-31
                           )
{
  const char * const status = IsInputPinHigh( pioPtr, pinNumber ) ? "high" : "low ";

  const uint8_t arduinoDuePinNumber = GetArduinoDuePinNumberFromPio( pioPtr, pinNumber );

  UsbPrint( txBuffer, "%s (pin %02u): %s", pinName, unsigned(arduinoDuePinNumber), status );
}


void PrintJtagPinStatus ( CUsbTxBuffer * const txBuffer )
{
  UsbPrint( txBuffer, "Input status of all JTAG pins:" EOL );

  PrintPinStatus( txBuffer, "TDI  ", JTAG_TDI_PIO, JTAG_TDI_PIN );
  UsbPrint( txBuffer, "  |  " );
  PrintPinStatus( txBuffer, "GND2 ", JTAG_GND2_PIO, JTAG_GND2_PIN );

  UsbPrint( txBuffer, EOL );

  UsbPrint( txBuffer, "%s (pin %02u): %s", " -   ", unsigned( GetArduinoDuePinNumberFromPio( PIOC, 19 ) ), " -  " );
  UsbPrint( txBuffer, "  |  " );
  PrintPinStatus( txBuffer, "nTRST", JTAG_TRST_PIO, JTAG_TRST_PIN );

  UsbPrint( txBuffer, EOL );

  PrintPinStatus( txBuffer, "TMS  ", JTAG_TMS_PIO, JTAG_TMS_PIN );
  UsbPrint( txBuffer, "  |  " );
  PrintPinStatus( txBuffer, "nSRST", JTAG_SRST_PIO, JTAG_SRST_PIN );

  UsbPrint( txBuffer, EOL );

  PrintPinStatus( txBuffer, "TDO  ", JTAG_TDO_PIO, JTAG_TDO_PIN );
  UsbPrint( txBuffer, "  |  " );
  PrintPinStatus( txBuffer, "VCC  ", JTAG_VCC_PIO, JTAG_VCC_PIN );

  UsbPrint( txBuffer, EOL );

  PrintPinStatus( txBuffer, "TCK  ", JTAG_TCK_PIO, JTAG_TCK_PIN );
  UsbPrint( txBuffer, "  |  " );
  PrintPinStatus( txBuffer, "GND1 ", JTAG_GND1_PIO, JTAG_GND1_PIN );

  UsbPrint( txBuffer, EOL );
}


void SetJtagPinMode ( const JtagPinModeEnum mode )
{
  switch ( mode )
  {
  case MODE_HIZ:
    // DbgconPrintStr( "Mode: HiZ." EOL );
    break;

  case MODE_JTAG:
    // DbgconPrintStr( "Mode: JTAG normal." EOL );
    break;

  case MODE_JTAG_OD:
    // DbgconPrintStr( "Mode: JTAG open-drain." EOL );
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
    //   DbgconPrintStr( "Feature: Voltage Regulator on." EOL );
    // else
    //   DbgconPrintStr( "Feature: Voltage Regulator off." EOL );

    break;

  case FEATURE_PULLUP:
    // if ( action == ACTION_ENABLE )
    //   DbgconPrintStr( "Feature: Pull-up resistors on." EOL );
    // else
    //   DbgconPrintStr( "Feature: Pull-up resistors off." EOL );

    SetJtagPullups( action == ACTION_ENABLE );

    break;

  case FEATURE_TRST:
    if ( false )
    {
      if ( action == ACTION_ENABLE )
        DbgconPrintStr( "Feature: TRST on." EOL );
      else
        DbgconPrintStr( "Feature: TRST off." EOL );
    }

    SetOutputDataDrivenOnPin( JTAG_TRST_PIO, JTAG_TRST_PIN, action == ACTION_ENABLE );

    break;

  case FEATURE_SRST:
    // We have not defined an SRST pin yet in our JTAG interface.
    if ( false )
    {
      if ( action == ACTION_ENABLE )
        DbgconPrintStr( "Feature: SRST on." EOL );
      else
        DbgconPrintStr( "Feature: SRST off." EOL );
    }

    SetOutputDataDrivenOnPin( JTAG_SRST_PIO, JTAG_SRST_PIN, action == ACTION_ENABLE );

    break;

  default:
    throw std::runtime_error( "Unknown feature in CMD_FEATURE." );
  }
}


static void SendOpenOcdModeWelcome ( CUsbTxBuffer * const txBuffer )
{
  txBuffer->WriteString( "OCD1" );
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
      DbgconPrint( "TDO stability check failed at iteration %i." EOL, int(i) );
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
    tdo8 = (tdo8 >> 1) | ( isTdoSet ? (1<<7) : 0 );
  }

  if ( TRACE_JTAG_SHIFTING )
    DbgconPrint( "TDI8: 0x%02X, TMS8: 0x%02X, TDO8: 0x%02X" EOL, tdi8, tms8, tdo8 );


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
      byteToSend = (byteToSend >> 1) | ( isTdoSet ? (1<<1) : 0 );
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
  // DbgconPrint( "TDI8: 0x%02X" EOL, tdi8 );
  // DbgconPrint( "TMS8: 0x%02X" EOL, tms8 );

  const uint8_t tdo1 = Shift2Bits( tdi8,      tms8 );
  const uint8_t tdo2 = Shift2Bits( tdi8 >> 2, tms8 >> 2 );
  const uint8_t tdo3 = Shift2Bits( tdi8 >> 4, tms8 >> 4 );
  const uint8_t tdo4 = Shift2Bits( tdi8 >> 6, tms8 >> 6 );

  const uint8_t tdo = ( tdo4 << 6 ) | ( tdo3 << 4 ) | ( tdo2 << 2 ) | tdo1;

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
  uint32_t remainingBytes = fullDataByteCount;

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

    const uint32_t maxIterationCount = MinFrom( MinFrom( maxReadCount / 2, maxWriteCount ), remainingBytes );

    // DbgconPrint( "It cnt: %u" EOL, unsigned( maxIterationCount ) );

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
    DbgconPrint( "--- Begin of JTAG shifting for %u bits ---" EOL, dataBitCount );

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
    DbgconPrintStr( "--- End of JTAG shifting ---" EOL );
}


static bool ShiftCommand ( CUsbRxBuffer * const rxBuffer,
                           CUsbTxBuffer * const txBuffer )
{
  uint8_t cmdHeader[ TAP_SHIFT_CMD_HEADER_LEN ];

  if ( !PeekCmdData( rxBuffer, cmdHeader, sizeof(cmdHeader) ) )
    return false;

  const uint8_t len1 = cmdHeader[ FIRST_PARAM_POS + 0 ];
  const uint8_t len2 = cmdHeader[ FIRST_PARAM_POS + 1 ];

  const uint16_t dataBitCount = (len1 << 8) | len2;

  // A command with more data bits than MAX_JTAG_TAP_SHIFT_BIT_COUNT will never fit
  // in the Rx Buffer, so we would be waiting forever for the command to be complete.

  if ( dataBitCount > MAX_JTAG_TAP_SHIFT_BIT_COUNT )
  {
    // The Bus Pirate firmware has a hard-coded limit of 0x2000.
    STATIC_ASSERT( MAX_JTAG_TAP_SHIFT_BIT_COUNT >= 0x2000, "We should support at least the Bus Pirate's maximum limit." );

    throw std::runtime_error( "CMD_TAP_SHIFT data len too big." );
  }


  const unsigned dataByteCount = ( dataBitCount + 7 ) / 8;
  const uint32_t cmdLen   = TAP_SHIFT_CMD_HEADER_LEN + dataByteCount * 2;
  const uint32_t replyLen = TAP_SHIFT_CMD_HEADER_LEN + dataByteCount;

  if ( rxBuffer->GetElemCount() < cmdLen   ||
       txBuffer->GetFreeCount() < replyLen )
  {
    return false;
  }

  rxBuffer->ConsumeReadElements( TAP_SHIFT_CMD_HEADER_LEN );

  // DbgconPrint( "CMD_TAP_SHIFT: %u bits." EOL, dataBitCount );

  STATIC_ASSERT( TAP_SHIFT_CMD_HEADER_LEN == 3, "Header size mismatch" );
  txBuffer->WriteElem( CMD_TAP_SHIFT );
  txBuffer->WriteElem( len1 );
  txBuffer->WriteElem( len2 );

  ShiftJtagData( rxBuffer, txBuffer, dataBitCount );

  return true;
}


static bool OpenOcdMode_ProcessData ( CUsbRxBuffer * const rxBuffer,
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
        // DbgconPrintStr( "CMD_PORT_MODE." EOL );
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
        // DbgconPrintStr( "CMD_FEATURE." EOL );
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
        // DbgconPrintStr( "CMD_UART_SPEED." EOL );

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
      DbgconPrint( "Unknown OpenOCD command with code %u (0x%02X).", cmdCode, cmdCode );
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
  // Note that this loop could then starve the main loop. If that becomes a problem, you will need
  // to limit the amount of data processed here.

  for ( ; ; )
  {
    const bool repeatIteration = OpenOcdMode_ProcessData( rxBuffer, txBuffer );

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

  assert( txBuffer->IsEmpty() );
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

#pragma once

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

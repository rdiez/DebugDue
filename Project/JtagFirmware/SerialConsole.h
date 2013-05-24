
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


// Include this header file only once.
#ifndef SERIAL_CONSOLE_H_INCLUDED
#define SERIAL_CONSOLE_H_INCLUDED

#include <stdint.h>

#include <BareMetalSupport/AssertionUtils.h>

#include "UsbBuffers.h"


// In the future, this class will become independent enough to help implement
// similar consoles in other environments.
//
// Still to do:
//  - Unicode support.
//  - Handle more keys like these: home, end, del, Ctrl+arrow keys.

class CSerialConsole
{
private:
  enum { BUF_LEN = 1024 };
  enum { MAX_SINGLE_CMD_LEN = 256 };  // Not including the NULL character terminator.

  // Maximum number of tx bytes that a single user edit operation may generate, approximately.
  enum { MAX_TX_BUFFER_SIZE_NEEDED = MAX_SINGLE_CMD_LEN + 40 };

  enum StateEnum
  {
    stIdle,
    stEscapeReceived,
    stEscapeBracketReceived
  };
  
  char m_buffer[ BUF_LEN ];  // Circular buffer with the current command and the past history of commands.

  uint32_t m_cmdBeginPos;  // First cmd character.
  uint32_t m_cmdEndPos;    // One position beyond the last cmd character, same as m_cmdBeginPos if empty.
  uint32_t m_cursorPos;    // Where the character is, so that m_cmdBeginPos <= m_cursorPos <= m_cmdEndPos
                           // (without taking into account the wrapping around at the end of the circular buffer).
  StateEnum m_state;

  void Bell ( CUsbTxBuffer * txBuffer );
  
  bool ProcessChar ( uint8_t c, CUsbTxBuffer * txBuffer );
  bool ProcessCharAfterEscapeBracket ( uint8_t c, CUsbTxBuffer * txBuffer );

  void LeftArrow  ( CUsbTxBuffer * txBuffer );
  void RightArrow ( CUsbTxBuffer * txBuffer );
  void Backspace  ( CUsbTxBuffer * txBuffer );
  void InsertChar ( uint8_t c, CUsbTxBuffer * txBuffer );

public:
  CSerialConsole ( void )
  {
    STATIC_ASSERT( MAX_SINGLE_CMD_LEN < BUF_LEN / 2, "Otherwise, the max single cmd len does not make much sense." );
    STATIC_ASSERT( MAX_TX_BUFFER_SIZE_NEEDED < USB_TX_BUFFER_SIZE, "Otherwise, there may not be enough space in the tx buffer to complete an operation like backspace." );
    Reset();
  }

  void Reset ( void );

  const char * AddChar ( uint8_t c,
                         CUsbTxBuffer * txBuffer,
                         uint32_t * cmdLen );
};


#endif  // Include this header file only once.

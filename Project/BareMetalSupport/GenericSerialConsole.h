
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

#pragma once

#include <stdint.h>

#include "AssertionUtils.h"


// Still to do:
//  - Unicode support.
//  - Handle more keys like these: home, end, del, Ctrl+arrow keys.

class CGenericSerialConsole
{
private:
  enum { BUF_LEN = 1024 };
  enum { MAX_SINGLE_CMD_LEN = 256 };  // Not including the NULL character terminator.

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

  void Bell ( void );

  bool ProcessChar ( uint8_t c );
  bool ProcessCharAfterEscapeBracket ( uint8_t c );

  void LeftArrow  ( void );
  void RightArrow ( void );
  void Backspace  ( void );
  void InsertChar ( uint8_t c );

  void PrintStr ( const char * str ) const;
  void PrintChar ( char c ) const;

  virtual void Printf ( const char * formatStr, ... ) const __attribute__ ((format(printf, 2, 3))) = 0;

 protected:
  // Maximum number of tx bytes that a single user edit operation may generate, approximately.
  enum { MAX_TX_BUFFER_SIZE_NEEDED = MAX_SINGLE_CMD_LEN + 40 };

public:
  CGenericSerialConsole ( void )
  {
    STATIC_ASSERT( MAX_SINGLE_CMD_LEN < BUF_LEN / 2, "Otherwise, the max single cmd len does not make much sense." );
    Reset();
  }

  void Reset ( void );

  const char * AddChar ( uint8_t c, uint32_t * cmdLen );
  void RepaintLine ( void ) const;
};

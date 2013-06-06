
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


#include "SerialConsole.h"  // The include file for this module should come first.

#include <algorithm>

#include <BareMetalSupport/AssertionUtils.h>
#include <BareMetalSupport/DebugConsole.h>
#include <BareMetalSupport/TextParsingUtils.h>

#include "Globals.h"


// Returns (end - begin), but takes into account a possible wrap-around at the end of the circular buffer.

static uint32_t GetCircularDistance ( const uint32_t begin,
                                      const uint32_t end,
                                      const uint32_t bufferSize )
{
  assert( begin < bufferSize );
  assert( end   < bufferSize );

  uint32_t ret;

  if ( begin <= end )
    ret = end - begin;
  else
    ret = ( bufferSize - begin ) + end;

  assert( ret < bufferSize );

  return ret;
}


static uint32_t GetCircularPosMinusOne ( const uint32_t pos,
                                         const uint32_t bufferSize )
{
  assert( pos < bufferSize );

  if ( pos > 0 )
    return pos - 1;
  else
    return bufferSize - 1;
}


void CSerialConsole::Reset ( void )
{
  m_state = stIdle;

  // Move the start position to BUF_LEN - 1 or a similar value
  // in order to test the circular buffer's wrap-around logic during development.
  const uint32_t startPos = 0;

  m_cmdBeginPos = startPos;
  m_cursorPos   = startPos;
  m_cmdEndPos   = startPos;

  for ( uint32_t i = 0; i < BUF_LEN; ++i )
    m_buffer[ i ] = 0;
}


void CSerialConsole::Bell ( CUsbTxBuffer * const txBuffer )
{
  txBuffer->WriteElem( 0x07 );
}


// Returns non-NULL if a command is ready to be executed. In this case,
// the circular buffer is rotated so that the command starts at the first buffer position.
//
// The rotation is a memory-intensive (slow) operation, but it simplifies the parsing code considerably,
// because the command parser can assume that the whole command lies in consecutive memory locations.
// Otherwise, the parsing logic gets tricky, or the caller needs to have yet another memory buffer
// while parsing the command, and memory is short on many embedded devices.
//
// As a possible optimisation, we could rotate only if the command is fragmented (wraps around the end
// of the circular buffer). However, every now and then a rotation must still take place. The user
// may then wonder why some commands take much longer than others to process.

const char * CSerialConsole::AddChar ( const uint8_t c,
                                       CUsbTxBuffer * const txBuffer,
                                       uint32_t * const retCmdLen )
{
  // Trace the incoming characters.
  if ( false )
  {
    if ( IsPrintableAscii(c) )
      DbgconPrint( "0x%02X (%3u, %c)" EOL, c, c, c  );
    else
      DbgconPrint( "0x%02X (%3u)" EOL, c, c );
  }

  bool isCmdReady = false;

  switch ( m_state )
  {
  case stIdle:
    isCmdReady = ProcessChar( c, txBuffer );
    break;

  case stEscapeReceived:
    if ( c == '[' )  // CSI (0x5B)
    {
      m_state = stEscapeBracketReceived;
    }
    else
    {
      Bell( txBuffer );
      m_state = stIdle;
    }
    break;

  case stEscapeBracketReceived:
    ProcessCharAfterEscapeBracket( c, txBuffer );
    break;

  default:
    assert( false );
    break;
  }

  if ( false )
  {
    DbgconPrint( "Char: 0x%02X, cmd begin: %u, end: %u, len: %u, pos: %u" EOL,
                 c,
                 unsigned( m_cmdBeginPos ),
                 unsigned( m_cmdEndPos ),
                 unsigned( GetCircularDistance( m_cmdBeginPos, m_cmdEndPos, BUF_LEN ) ),
                 unsigned( m_cursorPos ) );
  }

  if ( isCmdReady )
  {
    assert( m_cmdBeginPos < BUF_LEN );
    assert( m_cmdEndPos   < BUF_LEN );

    m_buffer[ m_cmdEndPos ] = 0;
    const uint32_t cmdLen = GetCircularDistance( m_cmdBeginPos, m_cmdEndPos, BUF_LEN );

    char * const first  = &m_buffer[0];
    char * const last   = &m_buffer[BUF_LEN];
    char * const middle = &m_buffer[m_cmdBeginPos];

    std::rotate( first, middle, last );

    assert( cmdLen < BUF_LEN );

    m_cmdBeginPos = cmdLen;
    m_cmdEndPos   = cmdLen;
    m_cursorPos   = cmdLen;

    // DbgconPrint( "Command ready." EOL );

    assert( strlen( m_buffer ) == cmdLen );

    *retCmdLen = cmdLen;
    return m_buffer;
  }
  else
  {
    *retCmdLen = 0;
    return NULL;
  }
}


bool CSerialConsole::ProcessChar ( const uint8_t c,
                                   CUsbTxBuffer * const txBuffer )
{
  // When the user inserts characters at the command's beginning,
  // a number of bytes are sent to the terminal, depending on the command length.

  bool isCmdReady = false;

  switch ( c )
  {
  case 0x1B: // Escape
    m_state = stEscapeReceived;
    break;

    // When you press the ENTER key, most terminal emulators send either a single LF or the (CR, LF) sequence.
  case 0x0A: // LF, \n
  case 0x0D: // Enter pressed (CR, \r)
    isCmdReady = true;
    break;

  case 0x02: // ^B (left arrow)
    LeftArrow( txBuffer );
    break;

  case 0x06: // ^F (right arrow)
    RightArrow( txBuffer );
    break;

  case 0x08: // Backspace (^H).
  case 0x7F: // For me, that's the backspace key.
    Backspace( txBuffer );
    break;

  default:
    InsertChar( c, txBuffer );
    break;
  }

  return isCmdReady;
}


void CSerialConsole::Backspace ( CUsbTxBuffer * const txBuffer )
{
  // If at the beginning, or if the command is empty...
  if ( m_cursorPos == m_cmdBeginPos )
  {
    Bell( txBuffer );
    return;
  }

  // If at the end...
  if ( m_cursorPos == m_cmdEndPos )
  {
    m_buffer[ m_cmdEndPos ] = 0;
    txBuffer->WriteString("\x08 \x08"); // Go left one character, space (deletes the character), go left one character again.
    m_cmdEndPos = GetCircularPosMinusOne( m_cmdEndPos, BUF_LEN  );
    m_cursorPos = m_cmdEndPos;
    return;
  }


  // NOTE: If the following logic changes much, remeber to update MAX_TX_BUFFER_SIZE_NEEDED.

  // Move the cursor left one position.
  m_cursorPos = GetCircularPosMinusOne( m_cursorPos, BUF_LEN );
  txBuffer->WriteString( "\x1B[D" );

  // Shift characters downwards one position, and print each one.
  for ( uint32_t i = m_cursorPos; i != GetCircularPosMinusOne( m_cmdEndPos, BUF_LEN ); i = ( i + 1 ) % BUF_LEN )
  {
    m_buffer[ i ] = m_buffer[ (i + 1) % BUF_LEN ];
    txBuffer->WriteElem( m_buffer[ i ] );
  }

  // Delete the last character by writing a space.
  txBuffer->WriteElem( ' ' );

  // Move the terminal cursor left to match our current cursor position.
  const uint32_t distanceToEnd = GetCircularDistance( m_cursorPos, m_cmdEndPos, BUF_LEN );
  if ( distanceToEnd > 0 )
    UsbPrint( txBuffer, "\x1B[%uD", unsigned( distanceToEnd ) );  // Move left n positions.

  m_cmdEndPos = GetCircularPosMinusOne( m_cmdEndPos, BUF_LEN );
}


void CSerialConsole::InsertChar ( const uint8_t c,
                                  CUsbTxBuffer * const txBuffer )
{
  // If not printable...
  if ( !IsPrintableAscii( c ) )
  {
    Bell( txBuffer );
    return;
  }

  const uint32_t nextEndPos = ( m_cmdEndPos + 1 ) % BUF_LEN;

  // If command full...
  if ( GetCircularDistance( m_cmdBeginPos, nextEndPos, BUF_LEN ) > MAX_SINGLE_CMD_LEN )
  {
    Bell( txBuffer );
    return;
  }

  // If the command is empty or the cursor is at the end, append the new character.
  if ( m_cursorPos == m_cmdEndPos )
  {
    m_buffer[ m_cmdEndPos ] = c;

    txBuffer->WriteElem( c );

    m_cursorPos = nextEndPos;
    m_cmdEndPos = nextEndPos;

    return;
  }


  // NOTE: If the following logic changes much, remeber to update MAX_TX_BUFFER_SIZE_NEEDED.

  // Shift characters upwards one position.
  for ( uint32_t i = nextEndPos; i != m_cursorPos; i = GetCircularPosMinusOne( i, BUF_LEN  ) )
    m_buffer[ i ] = m_buffer[ GetCircularPosMinusOne( i, BUF_LEN  ) ];

  // Insert new character.
  m_buffer[ m_cursorPos ] = c;

  // Print all characters.
  for ( uint32_t i = m_cursorPos; i != nextEndPos; i = ( i + 1 ) % BUF_LEN )
    txBuffer->WriteElem( m_buffer[ i ] );

  // Move the terminal cursor left to match our current cursor position.
  const uint32_t distanceToEnd = GetCircularDistance( m_cursorPos, m_cmdEndPos, BUF_LEN );
  assert( distanceToEnd > 0 );
  UsbPrint( txBuffer, "\x1B[%uD", unsigned( distanceToEnd ) );  // Move left n positions.

  m_cursorPos = (m_cursorPos + 1) % BUF_LEN;
  m_cmdEndPos = nextEndPos;
}


bool CSerialConsole::ProcessCharAfterEscapeBracket ( const uint8_t c,
                                                     CUsbTxBuffer * const txBuffer )
{
  switch (c)
  {
  case 'D':  LeftArrow ( txBuffer );  break;
  case 'C':  RightArrow( txBuffer );  break;

  default:
    Bell( txBuffer );
    break;
  }

  m_state = stIdle;

  return false;
}


void CSerialConsole::LeftArrow ( CUsbTxBuffer * const txBuffer )
{
  if ( m_cursorPos == m_cmdBeginPos )
  {
    Bell( txBuffer );
    return;
  }

  m_cursorPos = GetCircularPosMinusOne( m_cursorPos, BUF_LEN );

  txBuffer->WriteString( "\x1B[D" );  // Move left.
}


void CSerialConsole::RightArrow ( CUsbTxBuffer * const txBuffer )
{
  if ( m_cursorPos == m_cmdEndPos )
  {
    Bell( txBuffer );
    return;
  }

  m_cursorPos = ( m_cursorPos + 1 ) % BUF_LEN;

  txBuffer->WriteString( "\x1B[C" );  // Move right.
}

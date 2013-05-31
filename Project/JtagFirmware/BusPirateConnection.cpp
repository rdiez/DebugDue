
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


#include "BusPirateConnection.h"  // The include file for this module should come first.

#include <BareMetalSupport/MainLoopSleep.h>
#include <BareMetalSupport/DebugConsole.h>

#include "BusPirateConsole.h"
#include "BusPirateBinaryMode.h"
#include "BusPirateOpenOcdMode.h"
#include "Globals.h"


#ifndef NDEBUG
  static bool s_wasInitialised = false;
#endif

static BusPirateModeEnum s_busPirateMode = bpInvalid;

static const char * GetModeName ( const BusPirateModeEnum mode )
{
  switch ( mode )
  {
  case bpConsoleMode:  return "bpConsoleMode";
  case bpBinMode:      return "bpBinMode";
  case bpOpenOcdMode:  return "bpOpenOcdMode";

  default:
    assert( false );
    return "<unknown>";
  }
}


// txBufferForWelcomeMsg must be empty, see below for more information.

void ChangeBusPirateMode ( const BusPirateModeEnum newMode,
                           CUsbTxBuffer * const txBufferForWelcomeMsg )
{
  assert( s_busPirateMode != newMode );

  assert( s_busPirateMode != bpInvalid ||
          newMode         != bpInvalid );

  // Because mode switching speed is not important, all callers wait until the tx buffer is empty
  // before changing modes. That is the simplest way to make sure that there is enough space
  // in the tx buffer to hold the mode welcome message.
  if ( newMode == bpInvalid )
    assert( txBufferForWelcomeMsg == NULL );
  else
    assert( txBufferForWelcomeMsg->IsEmpty() );


  const bool TRACE_MODE_CHANGES = false;

  if ( TRACE_MODE_CHANGES && s_busPirateMode != bpInvalid )
  {
    DbgconPrint( "Leaving mode %s." EOL, GetModeName( s_busPirateMode ) );
  }


  switch ( s_busPirateMode )
  {
  case bpConsoleMode:  BusPirateConsole_Terminate();     break;
  case bpBinMode:      BusPirateBinaryMode_Terminate();  break;
  case bpOpenOcdMode:  BusPirateOpenOcdMode_Terminate(); break;

  case bpInvalid:
      break;

  default:
    assert( false );
    break;
  }


  if ( TRACE_MODE_CHANGES && newMode != bpInvalid )
  {
    DbgconPrint( "Entering mode %s." EOL, GetModeName( newMode ) );
  }


  s_busPirateMode = newMode;

  switch ( newMode )
  {
  case bpConsoleMode:  BusPirateConsole_Init    ( txBufferForWelcomeMsg ); break;
  case bpBinMode:      BusPirateBinaryMode_Init ( txBufferForWelcomeMsg ); break;
  case bpOpenOcdMode:  BusPirateOpenOcdMode_Init( txBufferForWelcomeMsg ); break;

  case bpInvalid:
    break;

  default:
    assert( false );
    break;
  }


  // After changing the mode, we should call the ProcessData() function once again.
  WakeFromMainLoopSleep();
}


void BusPirateConnection_ProcessData ( CUsbRxBuffer * const rxBuffer,
                                       CUsbTxBuffer * const txBuffer,
                                       const uint64_t currentTime )
{
  assert( s_wasInitialised );

  switch ( s_busPirateMode )
  {
  case bpConsoleMode:
    BusPirateConsole_ProcessData( rxBuffer, txBuffer, currentTime );
    break;

  case bpBinMode:
    BusPirateBinaryMode_ProcessData( rxBuffer, txBuffer );
    break;

  case bpOpenOcdMode:
    BusPirateOpenOcdMode_ProcessData( rxBuffer, txBuffer );
    break;

  default:
    assert( false );
    break;
  }
}


void BusPirateConnection_Init ( CUsbTxBuffer * const txBuffer )
{
  assert( !s_wasInitialised );

  #ifndef NDEBUG
    s_wasInitialised = true;
  #endif

  assert( txBuffer->IsEmpty() );
  ChangeBusPirateMode( bpConsoleMode, txBuffer );
}


void BusPirateConnection_Terminate ( void )
{
  assert( s_wasInitialised );

  ChangeBusPirateMode( bpInvalid, NULL );

#ifndef NDEBUG
   s_wasInitialised = false;
  #endif
}

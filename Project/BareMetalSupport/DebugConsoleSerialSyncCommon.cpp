
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


#include "DebugConsoleSerialSync.h"  // The include file for this module should come first.

#include <assert.h>

#include "IntegerPrintUtils.h"


void SerialSyncWriteStr ( const char * const msg ) throw()
{
  for ( const char * p = msg; *p != '\0'; ++p )
  {
    WriteSerialPortCharSync( *p );
  }
}


void SerialSyncWriteUint32Hex ( const uint32_t val ) throw()
{
  char hexBuffer[CONVERT_UINT32_TO_HEX_BUFSIZE];
  ConvertUint32ToHex( val, hexBuffer, false );
  SerialSyncWriteStr( hexBuffer );
}

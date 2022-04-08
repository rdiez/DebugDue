
// Copyright (C) 2020 R. Diez
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

#include <assert.h>

#include <BareMetalSupport/DebugConsoleSerialSync.h>


static volatile uint32_t * const UART0DR = (uint32_t *) 0x4000c000;

void WriteSerialPortCharSync ( const uint8_t c ) throw()
{
  // This only works under Qemu. On the real hardware, we would have to set the UART up
  // beforehand and check its flags before writing new data.
  // Alternatively, we could use Qemu's semihosting, see SYS_WRITEC and SYS_WRITE0.
  *UART0DR = c;
}

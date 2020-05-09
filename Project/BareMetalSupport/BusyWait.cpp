
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


#include "BusyWait.h"  // Include file for this module comes first.



// Checks that the assembly alignment directive is working properly for routine BusyWaitAsmLoop.

bool IsBusyWaitAsmLoopAligned ( void ) throw()
{
  // See the same symbol in assembly for more information.
  const uint8_t INSTRUCTION_LOAD_ALIGNMENT = 16;

  // Depending on the GCC optimisation level (-O0 vs -O1), the function address
  // has sometimes the extra 1 added or not.
  const uintptr_t THUMB_DISPLACEMENT = 1;

  uintptr_t fnAddr = uintptr_t( &BusyWaitAsmLoop );

  if ( 0 != ( fnAddr % 2 ) )
    fnAddr -= THUMB_DISPLACEMENT;

  return 0 == ( fnAddr % INSTRUCTION_LOAD_ALIGNMENT );
}

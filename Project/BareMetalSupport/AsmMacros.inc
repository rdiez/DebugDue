
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
#ifndef BMS_ASM_MACROS_H_INCLUDED
#define BMS_ASM_MACROS_H_INCLUDED


// On the Arduino Due we configure the CPU to load 128 bits (16 bytes) of instruction opcodes at a time from
// the internal Flash memory. Note that code alignment can have a major impact on performance
// on Cortex-M3 processors when executing tight loops.

#define INSTRUCTION_LOAD_ALIGNMENT 16


.macro GLOBAL_THUMB_FUNCTION name
    .thumb_func
    .balign 2
    .globl   \name
    .type    \name, %function
  \name:
.endm


#endif  // Include this file only once.

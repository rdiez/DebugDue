
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


#include "AsmMacros.inc"

    .text
    .syntax unified
    // We do not need to specify here .cpu cortex-m3 or .thumb, as they are passed from above as command-line arguments.
      

    // Function prototype:
    //   extern "C" void BusyWaitAsmLoop ( uint32_t iterationCount );

    // Instruction opcode alignment can have a big impact on performance.
    // Absolute speed is not important in this routine, but a loop iteration
    // must always take the same time across compilations, so set a big alignment
    // below in order to make sure that performance stays constant.
    //
    // The current implementation needs 3 clock cycles per iteration count
    // (after the first time, when the instruction prefetch buffer is loaded).
    // If that changes, make sure to adjust constant BUSY_WAIT_LOOP_ITER_PER_CLK_TICK
    // in the C++ counterpart.

    .balign INSTRUCTION_LOAD_ALIGNMENT

    GLOBAL_THUMB_FUNCTION BusyWaitAsmLoop

BusyWaitAsmLoop_1:
    subs    r0, #1
    bne     BusyWaitAsmLoop_1

    bx      lr


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

#pragma once


// These declarations match the linker script files.
//
// The memory layout depends on the microcontroller, and on your particular software needs.
// At the moment, we only support the Arduino Due and an emulated Stellaris LM3S6965EVB,
// and both share a similar layout. Their firmwares also have similar needs.
// However, some microcontrollers have different SRAM memory banks with different properties,
// so amending the linker script file is a very common thing to do.

extern "C" int _sfixed;  // The start of the interrupt vector table.

extern "C" int __etext;  // End of the code, and start of the data that needs to be relocated.
                         // Atmel or Arduino tend to name it '_etext'.

// This area is were the relocated data lands.
extern "C" int __data_start__;  // Atmel or Arduino tend to name it '_srelocate'.
extern "C" int __data_end__;    // Atmel or Arduino tend to name it '_erelocate'.

extern "C" int __bss_start__;  // Atmel or Arduino tend to name it '_sbss' or '_szero'.
extern "C" int __bss_end__;    // Atmel or Arduino tend to name it '_ebss' or '_ezero'.

extern "C" int __StackLimit;  // Start of the stack region, often called '_sstack'.
extern "C" int __StackTop;    // End   of the stack region (one byte beyond the end). This value lands in the "stack start" entry in the interrupt vector table.

extern "C" int __end__;      // Where the malloc heap starts. Atmel or Arduino tend to name it '_end'.
extern "C" int __HeapLimit;  // Where the malloc heap ends.

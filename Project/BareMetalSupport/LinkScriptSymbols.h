
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

// These link script symbol names seem to be standard for all ARM CPUs supported by the ARM CMSIS library.
// Other platforms have other names.

extern "C" int __etext;  // Atmel or Arduino tend to name it '_etext'.

extern "C" int __data_start__;  // Atmel or Arduino tend to name it '_srelocate'.
extern "C" int __data_end__;    // Atmel or Arduino tend to name it '_erelocate'.

extern "C" int __bss_start__;  // Atmel or Arduino tend to name it '_sbss' or '_szero'.
extern "C" int __bss_end__;    // Atmel or Arduino tend to name it '_ebss' or '_ezero'.

extern "C" int __StackTop;  // Atmel or Arduino tend to name it '_estack'.

extern "C" int __end__;  // Atmel or Arduino tend to name it '_end'.

extern "C" int _sfixed;  // The linker script files in the ARM CMSIS library do not seem to provide this symbol.

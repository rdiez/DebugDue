
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

#include <stddef.h>  // For size_t.
#include <stdint.h>

uintptr_t GetStackStartAddr ( void ) throw();
void SetStackSize ( size_t stackSize ) throw();

uintptr_t GetHeapEndAddr ( void ) throw();
void SetHeapEndAddr ( uintptr_t heapEndAddr ) throw();

void FillStackCanary ( void ) throw();
bool CheckStackCanary ( size_t canarySize ) throw() __attribute__ ((optimize("O2")));
size_t GetStackSizeUsageEstimate ( void ) throw();
size_t GetCurrentStackDepth ( void ) throw();

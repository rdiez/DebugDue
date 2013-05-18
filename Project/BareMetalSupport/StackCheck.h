
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
#ifndef BMS_STACK_CHECK_H_INCLUDED
#define BMS_STACK_CHECK_H_INCLUDED

#include <stddef.h>  // For size_t.
#include <stdint.h>

uintptr_t GetStackStartAddr ( void );
void SetStackSize ( size_t stackSize );

uintptr_t GetHeapEndAddr ( void );
void SetHeapEndAddr ( uintptr_t heapEndAddr );

void FillStackCanary ( void );
bool CheckStackCanary ( size_t canarySize );
size_t GetStackSizeUsageEstimate ( void );

#endif  // Include this header file only once.

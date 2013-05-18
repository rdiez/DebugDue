
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
#ifndef USB_SUPPORT_H_INCLUDED
#define USB_SUPPORT_H_INCLUDED

#include <stddef.h>

void InitUsb ( void );

bool IsUsbConnectionOpen ( void );

void UsbWriteData ( const void * data, size_t dataLen );
void UsbWriteStr ( const char * str );

void DiscardAllUsbData ( void );

#endif  // Include this header file only once.

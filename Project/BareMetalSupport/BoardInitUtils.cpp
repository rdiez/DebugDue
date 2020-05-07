
// Copyright (C) 2012-2020 R. Diez
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


#include "BoardInitUtils.h"  // Include file for this module comes first.

#include <assert.h>

#include <BareMetalSupport/AssertionUtils.h>


void RunUserCode ( void )
{
  #ifdef __EXCEPTIONS  // If the compiler supports C++ exceptions...

    try
    {
      StartOfUserCode();
    }
    catch ( ... )
    {
      Panic( "C++ exception from user code." );
    }

  #else

    StartOfUserCode();

  #endif
}

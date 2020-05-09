
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


#include "TextParsingUtils.h"  // The include file for this module should come first.


// Skips characters in a null-terminated string, normally used to skip blanks.

const char * SkipCharsInSet ( const char * str, const char * const charset ) throw()
{
  while ( *str != 0 && IsCharInSet( *str, charset ) )
    ++str;

  return str;
}


// Skips characters in a null-terminated string, normally used to skip text until the next group of blanks.

const char * SkipCharsNotInSet ( const char * str, const char * const charset ) throw()
{
  while ( *str != 0 && !IsCharInSet( *str, charset ) )
    ++str;

  return str;
}

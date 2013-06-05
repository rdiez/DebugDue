
#include "TextParsingUtils.h"  // The include file for this module should come first.


// Skips characters in a null-terminated string, normally used to skip blanks.

const char * SkipCharsInSet ( const char * str, const char * const charset )
{
  while ( *str != 0 && IsCharInSet( *str, charset ) ) 
    ++str;
    
  return str;
}


// Skips characters in a null-terminated string, normally used to skip text until the next group of blanks.

const char * SkipCharsNotInSet ( const char * str, const char * const charset )
{
  while ( *str != 0 && !IsCharInSet( *str, charset ) ) 
    ++str;
    
  return str;
}

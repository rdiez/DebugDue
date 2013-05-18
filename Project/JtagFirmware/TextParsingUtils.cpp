
#include "TextParsingUtils.h"  // The include file for this module should come first.

#include <string.h>


// Returns true if the given character is in the given character set.
//
// If you tend to use a fixed character set, it would be faster to use a look-up bitmap table,
// or a direct look-up table.
//
// NOTE: The NULL character is always considered to be in the set.
//

static inline bool IsCharInSet ( const char c, const char * const charset )
{
    return strchr( charset, c ) != NULL;
}


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

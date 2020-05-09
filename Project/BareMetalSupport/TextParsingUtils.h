#pragma once

#include <string.h>


const char * SkipCharsInSet ( const char * str, const char * char_set );
const char * SkipCharsNotInSet ( const char * str, const char * char_set );

inline bool IsPrintableAscii ( const char c )
{
  return ( c >= ' ' ) && ( c < 127 );
}


// Returns true if the given character is in the given character set.
//
// If you tend to use a fixed character set, it would be faster to use a look-up bitmap table,
// or a direct look-up table.
//
// NOTE: The NULL character is always considered to be in the set.
//

inline bool IsCharInSet ( const char c, const char * const charset )
{
    return strchr( charset, c ) != NULL;
}

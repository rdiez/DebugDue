// Include this header file only once.
#ifndef TEXT_PARSING_UTILS_H_INCLUDED
#define TEXT_PARSING_UTILS_H_INCLUDED

const char * SkipCharsInSet ( const char * str, const char * char_set );
const char * SkipCharsNotInSet ( const char * str, const char * char_set );

inline bool IsPrintableAscii ( const char c )
{
  return ( c >= ' ' ) && ( c < 127 );
}

#endif  // Include this header file only once.

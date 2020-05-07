// Include this header file only once.
#ifndef BMS_SERIAL_PRINT_H_INCLUDED
#define BMS_SERIAL_PRINT_H_INCLUDED

// These routines use the Serial Port Async Tx module, so they buffer
// the outgoing data and return straight away. The downside is, when the buffer
// overflows, data gets lost (but the user gets a warning message).

#include <stdarg.h>
#include <stddef.h>  // For size_t.

#include <BareMetalSupport/DebugConsoleEol.h>


void SerialPrintStr ( const char * msg );

void SerialPrintHexDump ( const void * ptr, size_t byteCount, const char * endOfLineChars );


// Beware that these routines consumes quite a lot of stack space,
// so use with care while in interrupt context.
#define MAX_SERIAL_PRINT_LEN 256
void SerialPrintf ( const char * formatStr, ... ) __attribute__ ((format(printf, 1, 2)));
void SerialPrintV ( const char * const formatStr, va_list argList );


#endif  // Include this header file only once.

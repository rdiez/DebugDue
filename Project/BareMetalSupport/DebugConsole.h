// Include this header file only once.
#ifndef DEBUG_PRINT_H_INCLUDED
#define DEBUG_PRINT_H_INCLUDED

#include <stdint.h>
#include <stddef.h>  // For size_t.
#include <stdarg.h>


void InitDebugConsole ( bool enableRxInterrupt );

void DbgconSyncWriteStr ( const char * msg );
void DbgconSyncWriteUint32Hex ( uint32_t val );
void DbgconWaitForDataSent ( void );

// This routine may become asynchronous in the future.
void DbgconPrintStr ( const char * msg );

// Beware that this routine consumes quite a lot of stack space,
// so use with care while in interrupt context.
#define MAX_DBGCON_PRINT_LEN 256
void DbgconPrint ( const char * formatStr, ... ) __attribute__ ((format(printf, 1, 2)));
void DbgconPrintV ( const char * const formatStr, va_list argList );

void DbgconHexDump ( const void * ptr, size_t byteCount, const char * endOfLineChars );

#endif  // Include this header file only once.

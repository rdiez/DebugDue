
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


#include <sys/types.h>  // For caddr_t.

#include <assert.h>  // For the function prototype of newlib's __assert_func().
#include <stdio.h>
#include <malloc.h>  // For M_TRIM_THRESHOLD.

#include <BareMetalSupport/LinkScriptSymbols.h>

#include "AssertionUtils.h"
#include "StackCheck.h"

extern "C" void _exit( int status ) ;
extern "C" void _kill( int pid, int sig ) ;
extern "C" int _getpid ( void ) ;
extern "C" caddr_t _sbrk( int incr ) ;

/* We should not need any of these. If you get linker errors about them, you are probably trying to use
   some C runtime library function that is not supported on our 'bare metal' environment.

extern "C" int _write( int file, char *ptr, int len ) ;
extern "C" int link( char *cOld, char *cNew ) ;
extern "C" int _close( int file ) ;
extern "C" int _fstat( int file, struct stat *st ) ;
extern "C" int _isatty( int file ) ;
extern "C" int _lseek( int file, int ptr, int dir ) ;
extern "C" int _read(int file, char *ptr, int len) ;
*/

static uintptr_t s_heapEndAddr = uintptr_t( &__end__ );  // At the beginning the heap is 0 bytes long.


caddr_t _sbrk ( const int incr )
{
    // I read somewhere that the increment can be negative, in order to release memory,
    // but I have yet to see this in real life, because the default value of
    // newlib's M_TRIM_THRESHOLD is rather high, if not disabled altogether.
    static_assert( M_TRIM_THRESHOLD == -1, "" );
    assert( incr >= 0 );  // If the value does indeed go negative, we need to adjust
                          // the code below (signed instead of unsigned integers and so on).
                          //
                          // Note that, during start-up, newlib may call with incr == 0,
                          // see sbrk_aligned() in newlib/libc/stdlib/nano-mallocr.c .

    const uintptr_t prevHeapEnd = s_heapEndAddr;

    if ( prevHeapEnd + incr > uintptr_t( &__HeapLimit ) )
    {
        Panic( "Out of heap memory." );
    }

    s_heapEndAddr += incr;

    return caddr_t( prevHeapEnd );
}


/*
int link ( char * cOld, char * cNew )
{
    return -1 ;
}

int _close( int file )
{
    return -1 ;
}

int _fstat ( int file, struct stat * st )
{
    st->st_mode = S_IFCHR ;

    return 0 ;
}

int _isatty ( int file )
{
    return 1 ;
}

int _lseek ( int file, int ptr, int dir )
{
    return 0 ;
}

int _read ( int file, char *ptr, int len )
{
    return 0 ;
}

int _write ( int file, char *ptr, int len )
{
    UNUSED_ALWAYS( file );
    UNUSED_ALWAYS( ptr );
    UNUSED_ALWAYS( len);
    // This function gets called through printf() and other standard I/O routines,
    // but they are not supported in our 'bare metal' environment, as they would
    // bring in too much C run-time library code.
    Panic("_write() called.");
    return -1;
}
*/


void _exit ( int status )
{
    UNUSED_ALWAYS( status );
    Panic("_exit() called.");
}


void _kill ( int pid, int sig )
{
    UNUSED_ALWAYS( pid );
    UNUSED_ALWAYS( sig );

    Panic("_kill() called.");
}


int _getpid ( void )
{
    Panic("_getpid() called.");
    return -1 ;
}


// The toolchain was built with flag HAVE_ASSERT_FUNC, so provide our own __assert_func() here,
// in case the user happens to include newlib's assert.h .

#ifndef NDEBUG

extern "C" void __assert_func ( const char * const filename,
                                const int line,
                                const char * const funcname,
                                const char * const failedexpr )
{
  char buffer[ ASSERT_MSG_BUFSIZE ];

  snprintf( buffer, sizeof(buffer),
            "Assertion \"%s\" failed at file %s, line %d%s%s.\n",
            failedexpr ? failedexpr : "<expr unavail>",
            filename,
            line,
            funcname ? ", function: " : "",
            funcname ? funcname : "" );

  Panic( buffer );
}


#ifndef INCLUDE_USER_IMPLEMENTATION_OF_ASSERT
  #error "INCLUDE_USER_IMPLEMENTATION_OF_ASSERT should be defined at this point."
#endif

extern "C" void __assert_func_only_file_and_line ( const char * const filename,
                                                   const int line )
{
  char buffer[ ASSERT_MSG_BUFSIZE ];

  // Wir geben hier kein DEBUG_OUTPUT_EOL vorne und hinten, weil Panic() es bereits macht.

  snprintf( buffer, sizeof(buffer),
            "Assertion failed at file %s, line %d.",
            filename,
            line );

  Panic( buffer );
}


extern "C" void __assert_func_generic_err_msg ( void )
{
  Panic( "Assertion failed." );
}

#endif  // #ifndef NDEBUG

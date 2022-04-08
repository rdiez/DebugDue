
// Copyright (C) 2012-2021 R. Diez
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

#include <newlib.h>  // For _PICOLIBC__, if we are actually using Picolibc.

#include <unistd.h>  // For _exit(). For Picolibc, for sbrk() and getpid() too.

#ifdef _PICOLIBC__
  #include <signal.h>  // For kill().
#endif

#include <assert.h>  // For the function prototype of Newlib's __assert_func().
#include <stdio.h>
#include <stdlib.h>  // For abort().

#include <BareMetalSupport/LinkScriptSymbols.h>

#if ! IS_QEMU_FIRMWARE
  #include <BareMetalSupport/Miscellaneous.h>
#endif

#include "AssertionUtils.h"


#ifndef _PICOLIBC__

  // In the case of Newlib's nano allocator, the prototype for _sbrk() is declared within _sbrk_r(),
  // so there is no header file we could include for it.
  extern "C" void * _sbrk ( ptrdiff_t );

  // I do not know what Newlib header file could provide these prototypes.
  extern "C" pid_t _getpid ( void );
  extern "C" int _kill ( pid_t, int );

#endif


static uint8_t * s_heapEndAddr = (uint8_t *) &__end__;  // At the beginning the heap is 0 bytes long.


void *
  #ifdef _PICOLIBC__
    sbrk
  #else
    _sbrk
  #endif
  ( const ptrdiff_t incr )
{
  // Malloc is generally not safe in interrupt context.
  // You would normally do this kind of check inside a malloc() hook,
  // but not all malloc implementations offer such hooks

  // We do not have the necessary CMSIS routines available in the QEMU project yet.
  #if ! IS_QEMU_FIRMWARE
    assert( ! IsCpuHandlingAnInterrupt() );
  #endif


  // Note that, during start-up, Newlib may call with incr == 0,
  // see sbrk_aligned() in newlib/libc/stdlib/nano-mallocr.c .

  uint8_t * const prevHeapEnd = s_heapEndAddr;

  bool isOutOfMemory;

  if ( incr < 0 )
  {
    assert( false );  // Releasing memory is theoretically possible, but very rare. See malloc_trim().

    isOutOfMemory = prevHeapEnd - (uint8_t *) &__end__ < -incr;

    // The allocator should actually never release more memory than it has allocated.
    assert( !isOutOfMemory );
  }
  else
  {
    isOutOfMemory = (uint8_t *) &__HeapLimit - prevHeapEnd < incr;
  }

  if ( isOutOfMemory )
  {
    // An out-of-memory situation is probably going to wreak havoc,
    // and it should never happen in well-designed firmware.
    // But if you trust your firmware, you can return an error instead.
    if ( true )
    {
      Panic( "Out of heap memory." );
    }
    else
    {
      return (void *) -1;
    }
  }

  s_heapEndAddr += incr;

  return prevHeapEnd;
}


/* We should not need any of these. If you get linker errors about them, you are probably trying to use
   some C runtime library function that is not supported on our 'bare metal' environment.

extern "C" int link ( char * cOld, char * cNew )
{
    return -1 ;
}

extern "C" int _close( int file )
{
    return -1 ;
}

extern "C" int _fstat ( int file, struct stat * st )
{
    st->st_mode = S_IFCHR ;

    return 0 ;
}

extern "C" int _isatty ( int file )
{
    return 1 ;
}

extern "C" int _lseek ( int file, int ptr, int dir )
{
    return 0 ;
}

extern "C" int _read ( int file, char *ptr, int len )
{
    return 0 ;
}

extern "C" int _write ( int file, char *ptr, int len )
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


extern "C" void _exit ( int status )
{
    UNUSED_ALWAYS( status );
    Panic("_exit() called.");
}


int
  #ifdef _PICOLIBC__
    kill
  #else
    _kill
  #endif
   ( pid_t pid, int sig )
{
  UNUSED_ALWAYS( pid );
  UNUSED_ALWAYS( sig );

  Panic("_kill() called.");
}


pid_t
  #ifdef _PICOLIBC__
    getpid
  #else
    _getpid
  #endif
  ( void )
{
    Panic("_getpid() called.");
    return -1 ;
}

*/


__attribute__ ((__noreturn__))
void abort ( void )
{
  Panic("abort() called.");
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

  // Panic() automatically adds a new-line character at the end.

  snprintf( buffer, sizeof(buffer),
            "Assertion \"%s\" failed at file %s, line %d%s%s.",
            failedexpr ? failedexpr : "<expr unavail>",
            filename,
            line,
            funcname ? ", function: " : "",
            funcname ? funcname : "" );

  Panic( buffer );
}


// I haven't written support for ASSERT_TYPE for Picolibc yet.
#ifndef _PICOLIBC__

#ifndef INCLUDE_USER_IMPLEMENTATION_OF_ASSERT
  #error "INCLUDE_USER_IMPLEMENTATION_OF_ASSERT should be defined at this point."
#endif

extern "C" void __assert_func_only_file_and_line ( const char * const filename,
                                                   const int line )
{
  char buffer[ ASSERT_MSG_BUFSIZE ];

  // Panic() automatically adds a new-line character at the end.

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

#endif  // #ifndef _PICOLIBC__

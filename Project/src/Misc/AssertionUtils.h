
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

#pragma once

#if defined(DEBUG) && defined(NDEBUG)
#error "Both DEBUG and NDEBUG are defined."
#endif

#if !defined(DEBUG) && !defined(NDEBUG)
#error "Either DEBUG or NDEBUG must be defined."
#endif

// You would normally use "#ifndef NDEBUG" in order to conditionally compile extra code in debug builds.
// The drawback of using #ifdef is that the compiler completely skips compilation, which easily
// leads to code rot, because any eventual syntax errors in the skipped parts will not be immediately
// detected. Using normal 'if' statements with helper routine 'IsDebugBuild()' below solves that problem.
#ifdef __cplusplus
inline bool IsDebugBuild ( void ) throw()
{
  #ifndef NDEBUG
    return true;
  #else
    return false;
  #endif
}
#endif


#include <assert.h>  //  For the assert() call in the VERIFY macro below.


// This static assert definition comes from http://www.pixelbeat.org/programming/gcc/static_assert.html
// We could use GCC's built-in static_assert, but we would need to enable it with -std=c++0x,
// which is still marked as experimental in GCC 4.7.3.

#define ASSERT_CONCAT_(a, b) a##b
#define ASSERT_CONCAT(a, b) ASSERT_CONCAT_(a, b)
/* These can't be used after statements in c89. */
#ifdef __COUNTER__
  #define STATIC_ASSERT(e,m) \
    { enum { ASSERT_CONCAT(static_assert_, __COUNTER__) = 1/(!!(e)) }; }
#else
  /* This can't be used twice on the same line so ensure if using in headers
   * that the headers are not included twice (by wrapping in #ifndef...#endif)
   * Note it doesn't cause an issue when used on same line of separate modules
   * compiled with gcc -combine -fwhole-program.  */
  #define STATIC_ASSERT(e,m) \
    { enum { ASSERT_CONCAT(assert_line_, __LINE__) = 1/(!!(e)) }; }
#endif


// Macros UNUSED_ALWAYS, VERIFY and UNUSED are very popular under Windows, and I have got used to them.
// NOTE: UNUSED() is defined by libsam. Under Windows it means "unused in release builds",
//       but in libsam it means "unused always". Therefore, instead of UNUSED,
//       it is called UNUSED_IN_RELEASE here.

#define UNUSED_ALWAYS(x) ( (void)(x) )

#ifdef NDEBUG
  #define VERIFY(f) ( (void)(f) )
  #define UNUSED_IN_RELEASE(x) ( (void)(x) )
#else
  #define VERIFY(f) assert(f)
  #define UNUSED_IN_RELEASE(x)
#endif


// Panic support.
//
// These routines are extern "C" so that they can be called from C-only code you may be using.
// For example, the lwIP library has its own assert symbol that you can customize so that
// it calls Panic() below, but the library compiles in C mode.

extern "C"
{
  typedef void (*UserPanicMsgFunction) ( const char * msg );

  void SetUserPanicMsgFunction ( UserPanicMsgFunction functionPointer ) throw();

  void Panic ( const char * msg )  throw()__attribute__ ((__noreturn__));

  void ForeverHangAfterPanic ( void )  throw()__attribute__ ((__noreturn__));
}

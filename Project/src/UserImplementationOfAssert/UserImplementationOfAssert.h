
// This file must not have a multiple inclusion guard like this:
//
//   #pragma once
//
// It turns out that every #include <assert.h> will redefine the 'assert' macro.
// That is, Newlib's assert.h has no global multiple inclusion guard
// and does "#undef assert" before (re)defining assert.
//
// As this file gets included at the end of assert.h, that is why we can #undef assert
// here again and redefine it one more time.


// Most of this file only needs to be processed once.
// Defining macros multiple times with the same value does not usually matter,
// but we would get "redundant redeclaration" warnings for the functions.
#ifndef ASSERT_FUNC_ETC_WAS_DEFINED
#define ASSERT_FUNC_ETC_WAS_DEFINED

  // This kind makes debug builds pretty big, but provides the most comfortable failed assertion messages.
  #define ASSERT_TYPE_FULL                1

  // This kind reduces the code side in debug builds quite a lot, while still providing good
  // information about failed assertions.
  #define ASSERT_TYPE_ONLY_FILE_AND_LINE  2

  // This kind reduces the code side in debug builds drastically, but a generic error message
  // does not really help much. It is only really useful when the debug build is running under a debugger.
  #define ASSERT_TYPE_GENERIC_ERR_MSG     3

  // This kind implements assertions with a minimal footprint.
  // Because of the ARM Cortex-Mx 'bkpt' instruction below, failed assertions generate the same message
  // as normal crashes if a debugger is not attached, so this is only really useful when the debug build
  // is running under a debugger.
  #define ASSERT_TYPE_DEBUG_BREAK         4


  #ifndef ASSERT_TYPE
    #error "Macro 'ASSERT_TYPE' should be defined at this point."
  #endif


  #ifdef __cplusplus
  extern "C" {
  #endif

    // We need separate routines in order to save space, because passing parameters also needs some code.
    void __assert_func_only_file_and_line ( const char * filename, int line );
    void __assert_func_generic_err_msg ( void );

  #ifdef __cplusplus
  }  // extern "C" {
  #endif


  __attribute__((always_inline))  // Save program space, because this routine is really small.
  inline void __assert_func_debug_break ( void )
  {
    // Alternatively, see CMSIS' __BKPT() and GCC's intrinsic __builtin_trap().
    __asm__ volatile( "bkpt 0" );
  }

#endif  // #ifndef ASSERT_FUNC_ETC_WAS_DEFINED


#ifndef assert
  #error "Macro 'assert' should be defined at this point."
#endif

#undef assert

#define IS_ASSERT_TYPE_HONOURED  true

#ifdef NDEBUG  // Required by the ANSI standard.

  #define assert(__e) ((void)0)

#else  // #ifdef NDEBUG

  #if ASSERT_TYPE == ASSERT_TYPE_FULL

    #define assert(expression) ( (expression) ? (void) 0 : __assert_func( __FILE__, __LINE__, __FUNCTION__, #expression ) )

  #elif ASSERT_TYPE == ASSERT_TYPE_ONLY_FILE_AND_LINE

    #define assert(expression) ( (expression) ? (void) 0 : __assert_func_only_file_and_line( __FILE__, __LINE__ ) )

  #elif ASSERT_TYPE == ASSERT_TYPE_GENERIC_ERR_MSG

    #define assert(expression) ( (expression) ? (void) 0 : __assert_func_generic_err_msg() )

  #elif ASSERT_TYPE == ASSERT_TYPE_DEBUG_BREAK

    #define assert(expression) ( (expression) ? (void) 0 : __assert_func_debug_break() )

  #else

    #error "Unknown ASSERT_TYPE."

  #endif

#endif  // #ifdef NDEBUG


#include <BoardSupport-LM3S6965EVB/AngelInterface.h>  // Include file for this module comes first.

#include <Misc/AssertionUtils.h>


  // __attribute__ ((noinline))  // Not inlining can be helpful while debugging this routine.
static int CallAngel ( const int operation, const int arg1, const int arg2 ) throw()
{
  register int r0 __asm__("r0") = operation;
  register int r1 __asm__("r1") __attribute__((unused)) = arg1;
  register int r2 __asm__("r2") __attribute__((unused)) = arg2;
  register int result __asm__ ("r0");  // We are using another name for R0. There is a similar example in the GCC documentation.

  __asm__ volatile(

     // Use instruction BKTP for ARMv6-M and ARMv7-M, Thumb state only.
     // Otherwise, instruction SVC (previously called SWI) is normally used instead.
     "BKPT 0xAB"  // Code 0xAB triggers semihosting processing.

     // Output operand list
     : "=r"(result)

     // Input operand list
     : "0" (r0),  // At the same position as output operand 0, therefore R0 ('result').
       "r" (r1),
       "r" (r2)

     // Clobber list
     :  // I do not think that any registers or flags are modified.
        // As an example, we could use "cc", which means "The instruction affects the condition code flags".
  );

  return result;
}


// About the exit code, according to some documentation I found in some source code:
//
//   The A64 version of SYS_EXIT takes a parameter block,
//   so the application-exit type can return a subcode which
//   is the exit status code from the application.
//   SYS_EXIT_EXTENDED is an a new-in-v2.0 optional function
//   which allows A32/T32 guests to also provide a status code.
//
//   The A32/T32 version of SYS_EXIT specifies only
//   Stopped_ApplicationExit as normal exit, but does not
//   allow the guest to specify the exit status code.
//   Everything else is considered an error.
//
static const int ADP_Stopped_ApplicationExit = 0x20026;
static const int EXIT_CODE_SUCCESS = 0;
static const int EXIT_CODE_FAILURE = 1;

void Angel_ExitApp ( void ) throw()
{
  // See also TARGET_SYS_EXIT_EXTENDED (0x20), which allows an 8-bit exit status code.
  const int TARGET_SYS_EXIT = 0x18;

  const int exitCodeForA64 = EXIT_CODE_SUCCESS;  // Ignored for A32/T32.

  CallAngel( TARGET_SYS_EXIT, ADP_Stopped_ApplicationExit, exitCodeForA64 );

  Panic( "Unexpected." );
}

void Angel_ExitAppWithFailureIndication ( void ) throw()
{
  const int TARGET_SYS_EXIT_EXTENDED = 0x20;

  // I could not get this to work properly with QEMU 6.2.0, the exit code is not honoured.
  // Perhaps TARGET_SYS_EXIT_EXTENDED is not supported at all by that QEMU version.
  // In any case, the exit code happens to always be 1, which helps us signal an error.
  //
  // Alternatively, the combination TARGET_SYS_EXIT with something other
  // than ADP_Stopped_ApplicationExit should also cause an exit code of 1.

  CallAngel( TARGET_SYS_EXIT_EXTENDED, ADP_Stopped_ApplicationExit, EXIT_CODE_FAILURE );

  Panic( "Unexpected." );
}

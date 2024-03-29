
#include <BoardSupport-LM3S6965EVB/AngelInterface.h>  // Include file for this module comes first.

#include <Misc/AssertionUtils.h>


static const int UNUSED_ARG = 0;


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


void Angel_ExitApp ( void ) throw()
{
  // See also TARGET_SYS_EXIT_EXTENDED (0x20), which allows an 8-bit exit status code.
  const int TARGET_SYS_EXIT = 0x18;

  const int ADP_Stopped_ApplicationExit = 0x20026;

  CallAngel( TARGET_SYS_EXIT, ADP_Stopped_ApplicationExit, UNUSED_ARG );

  Panic( "Unexpected." );
}

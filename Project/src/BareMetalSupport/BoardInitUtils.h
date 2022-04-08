
#pragma once

// The user must provide this routine.
void StartOfUserCode ( void );

// Tell GCC never to inline this routine. It may not be necessary,
// but I just want to make sure the stack frame and C++ exception frame
// are correct at this point. The caller routine initialises them,
// therefore, if GCC makes assumptions and reorder code, it may not be right
// before this routine is called.

void RunUserCode ( void ) throw() __attribute__ ((noinline));

void InitDataSegments ( void ) throw();

void PrintFirmwareSegmentSizesSync  ( void ) throw();
void PrintFirmwareSegmentSizesAsync ( void ) throw();
void RuntimeStartupChecks ( void ) throw();
void RuntimeTerminationChecks ( void ) throw();

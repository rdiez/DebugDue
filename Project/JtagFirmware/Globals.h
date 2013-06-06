// Include this header file only once.
#ifndef GLOBALS_H_INCLUDED
#define GLOBALS_H_INCLUDED

#define STACK_SIZE (1024 * 4)

// This is the end-of-line character used in both debug and Bus Pirate consoles.
// We could send just an LF, but the Bus Pirate sends CR LF, see routine bpWline() in baseIO.c .
#define EOL "\r\n"  // Carriage Return, 0x0D, followed by a Line Feed, 0x0A.

static const bool ENABLE_WDT = true;

#define SYSTEM_TICK_PERIOD_MS  50

#endif  // Include this header file only once.

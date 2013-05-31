// Include this header file only once.
#ifndef GLOBALS_H_INCLUDED
#define GLOBALS_H_INCLUDED

#define STACK_SIZE (1024 * 4)

// This is the end-of-line character used in both debug and Bus Pirate consoles.
// We could send just an LF, but the Bus Pirate sends CR LF, see routine bpWline() in baseIO.c .
#define EOL "\r\n"  // Carriage Return, 0x0D, followed by a Line Feed, 0x0A.


// The watchdog triggers while stopped at a GDB breakpoint, but it should not,
// so that is the reason why I have disabled it for the time being.
// If you know how to change this behaviour, please drop me a line.
static const bool ENABLE_WDT = false;

#endif  // Include this header file only once.

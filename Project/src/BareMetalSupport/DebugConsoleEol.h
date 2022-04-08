
#pragma once

// This is the end-of-line character used in both debug and Bus Pirate consoles.
// We could send just an LF, but the Bus Pirate sends CR LF, see routine bpWline() in baseIO.c .
#define EOL "\r\n"  // Carriage Return, 0x0D, followed by a Line Feed, 0x0A.


#pragma once

// This module uses the Angel interface for ARM processors.
// Our main target is Qemu's semihosting.

void Angel_ExitApp ( void ) throw() __attribute__ ((__noreturn__));


// The linker automatically adds crt0.o to the list of files to link.
// We have disabled libgloss when building the toolchain, so crt0.o is not there.
// This empty file should do the trick though.
//
// I haven't found a way yet to disable in GCC the automatic inclusion of crt0.o .
// GCC does have flag "-mno-crt0" for one of the targets, not not for ARM.
//
// Alternatively, you could experiment with GCC flag "-nostartfiles",
// but I fear that it would break C++ support by not initialising
// global objects properly.

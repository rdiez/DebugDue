
// The linker automatically adds crt0.o to the list of files to link.
// We have disabled libgloss when building the toolchain, so crt0.o is not there.
// This empty file should do the trick though.
// I haven't found a way yet to disable the automatic inclusing of crt0.o at GCC level.

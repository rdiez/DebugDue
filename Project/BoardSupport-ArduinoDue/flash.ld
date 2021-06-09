/* ----------------------------------------------------------------------------
 *         SAM Software Package License
 * ----------------------------------------------------------------------------
 * Copyright (c) 2012, Atmel Corporation
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following condition is met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the disclaimer below.
 *
 * Atmel's name may not be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * DISCLAIMER: THIS SOFTWARE IS PROVIDED BY ATMEL "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT ARE
 * DISCLAIMED. IN NO EVENT SHALL ATMEL BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * ----------------------------------------------------------------------------


 This linker script file was taken from the Arduino software version 1.5.2,
 with some changes by rdiez.
*/

OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)
SEARCH_DIR(.)

MEMORY
{
	rom (rx)    : ORIGIN = 0x00080000, LENGTH = 0x00080000 /* Flash, 512K */
	/* sram0 (rwx) : ORIGIN = 0x20000000, LENGTH = 0x00010000 / * sram0, 64K */
	/* sram1 (rwx) : ORIGIN = 0x20080000, LENGTH = 0x00008000 / * sram1, 32K */
	ram (rwx)   : ORIGIN = 0x20070000, LENGTH = 0x00018000 /* sram, 96K */
}

/* Section Definitions */
SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        _sfixed = .;
        KEEP(*(.vectors .vectors.*))
        *(.text .text.* .gnu.linkonce.t.*)
        *(.glue_7t) *(.glue_7)
        *(.rodata .rodata* .gnu.linkonce.r.*)
        *(.ARM.extab* .gnu.linkonce.armextab.*)

        /* Support C constructors, and C destructors in both user code
           and the C library. This also provides support for C++ code. */
        . = ALIGN(4);
        KEEP(*(.init))
        . = ALIGN(4);
        __preinit_array_start = .;
        KEEP (*(.preinit_array))
        __preinit_array_end = .;

        . = ALIGN(4);
        __init_array_start = .;
        /* If you use "__attribute__ ((constructor (200)))", GCC generates a name like ".init_array.00200".
           Objects with a priority are constructed before objects without priority. */
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array))
        __init_array_end = .;

        . = ALIGN(0x4);
        KEEP (*crtbegin.o(.ctors))
        KEEP (*(EXCLUDE_FILE (*crtend.o) .ctors))
        KEEP (*(SORT(.ctors.*)))
        KEEP (*crtend.o(.ctors))

        . = ALIGN(4);
        KEEP(*(.fini))

        . = ALIGN(4);
        __fini_array_start = .;
        /* .fini_array must be sorted the same as .init_array. The C code will process it from bottom to top,
           so that the destruction order is the reverse of the construction order. */
        KEEP (*(SORT(.fini_array.*)))
        KEEP (*(.fini_array))
        __fini_array_end = .;

        KEEP (*crtbegin.o(.dtors))
        KEEP (*(EXCLUDE_FILE (*crtend.o) .dtors))
        KEEP (*(SORT(.dtors.*)))
        KEEP (*crtend.o(.dtors))

        . = ALIGN(4);
        _efixed = .;            /* End of text section */
    } > rom

    /* This is the exception index table. It is mainly needed for C++ exception support. Option "-funwind-tables"
       also generates these tables, which are useful if your C code wants to print a stack backtrace.
       The whole .ARM.exidx group is sorted by the linker, and I think duplicates are also collapsed together,
       so has to go in its own output section. */
    __exidx_start = .;
    .ARM.exidx :
    {
      *(.ARM.exidx* .gnu.linkonce.armexidx.*)
    } > rom
    __exidx_end = .;

    . = ALIGN(4);
    __etext = .;
    /* At the end of the ROM/Flash area, after __etext, lies the data that will be relocated to RAM
       on start-up, see .relocate below. */


    /* Place the stack at the beginning of some hardware RAM barrier. This way, a stack overflow will immediately
       crash the application, instead of corrupting data and making troubleshooting harder. */

    StackAlignment = 8;  /* Must be at least 4. There is an optional flag in the Cortex-M3 core to reduce alignment from 8 to 4,
                            so I think that 8 is a good choice here. */
    . = ORIGIN( ram );

    .stackArea ALIGN( StackAlignment ) (NOLOAD):
    {
        __StackLimit = .;
        KEEP(*(.placeInStackArea))
        __StackTop = .;
    } > ram

    /* After some time working on linker script files, you develop acute paranoia.
       Therefore, check that the stack values look plausible. */
    StackAssert1 = ASSERT( SIZEOF(.stackArea) >=  1 * 1024, "Stack area too small.");
    StackAssert2 = ASSERT( SIZEOF(.stackArea) <= 50 * 1024, "Stack area too big.");
    StackAssert3 = ASSERT( __StackTop > __StackLimit, "Wrong stack area address.");


    .relocate : AT (__etext)
    {
        . = ALIGN(4);
        __data_start__ = .;

        *(.data)
        *(.data.*);

        . = ALIGN(4);
        __data_end__ = .;
    } > ram

    /* .bss section which is used for uninitialized data */
    .bss ALIGN(4) (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
    } > ram

    . = ALIGN(8);
    __end__ = . ;  /* Symbol __end__ marks the start of the malloc heap. */
    __HeapLimit = ORIGIN(ram) + LENGTH(ram);
}

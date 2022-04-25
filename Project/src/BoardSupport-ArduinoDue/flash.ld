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

MEMORY
{
        rom (rx)    : ORIGIN = 0x00080000, LENGTH = 0x00080000 /* Flash, 512K */
        /* sram0 (rwx) : ORIGIN = 0x20000000, LENGTH = 0x00010000 / * sram0, 64K */
        /* sram1 (rwx) : ORIGIN = 0x20080000, LENGTH = 0x00008000 / * sram1, 32K */
        ram (rwx)   : ORIGIN = 0x20070000, LENGTH = 0x00018000 /* sram, 96K */
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        _sfixed = .;
        KEEP(*(.vectors .vectors.*))
        *(.text .text.* .gnu.linkonce.t.*)  /* All ".gnu.linkonce" sections are used for C++ "vague linkage" */
        *(.glue_7t) *(.glue_7)
        *(.rodata .rodata* .gnu.linkonce.r.*)
        *(.ARM.extab* .gnu.linkonce.armextab.*)


        /* Support C constructors and destructors in both user code and the C runtime library.
           This also provides support for C++ constructors and destructors. */

        _section_init_start = .;
        KEEP(*(.init))
        _section_init_end = .;

        _section_fini_start = .;
        KEEP(*(.fini))
        _section_fini_end = .;

        /* Sections .init and .fini are used to dynamically build functions _init() and _fini().
           We are not calling these functions, and they should not be initialising anything.
           Such empty routines look like this for the Thumb instruction set:
             push    {r3, r4, r5, r6, r7, lr}
             nop
             pop     {r3, r4, r5, r6, r7}
             pop     {r3}
             mov     lr, r3
             bx      lr
             That code needs 12 bytes.
        */
        ASSERT( _section_init_end - _section_init_start == 12, "The .init section is not (almost) empty." );
        ASSERT( _section_fini_end - _section_fini_start == 12, "The .fini section is not (almost) empty." );


        . = ALIGN(4);
        __preinit_array_start = .;
        KEEP (*(.preinit_array))
        __preinit_array_end = .;

        . = ALIGN(4);
        /* We are not using .ctors/.dtors, but the alternative .init_array/.fini_array.
           Unfortunately, I haven't found out yet how to check in the application's
           source code wheter INIT_SECTION_ASM_OP is defined, to be sure. */
        __init_array_start = .;
        /* If you use "__attribute__ ((constructor (200)))", GCC generates a name like ".init_array.00200".
           Alternatively, you can use SORT_BY_INIT_PRIORITY, but with the naming scheme that GCC uses,
           the results would be the same. */
        KEEP (*(SORT(.init_array.*)))
        /* Objects with a priority are constructed before objects without priority. */
        KEEP (*(.init_array))
        __init_array_end = .;

        . = ALIGN(4);
        __fini_array_start = .;
        /* .fini_array must be sorted the same as .init_array. The C code will process it from bottom to top,
           so that the destruction order is the reverse of the construction order. */
        KEEP (*(SORT(.fini_array.*)))
        KEEP (*(.fini_array))
        __fini_array_end = .;

        . = ALIGN(4);
        _efixed = .;            /* End of text section */
    } > rom

    /* This is the exception index table. It is mainly needed for C++ exception support. Option "-funwind-tables"
       also generates these tables, which are useful if your C code wants to print a stack backtrace.
       The whole .ARM.exidx group is sorted by the linker, and I think duplicates are also collapsed together,
       so has to go in its own output section. */
    __exidx_start = .;  /* libgcc references __exidx_start and __exidx_end, but that seems to be specific to the ARM architecture. */
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

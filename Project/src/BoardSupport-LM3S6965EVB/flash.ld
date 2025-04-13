/******************************************************************************
 * @file     gcc_arm.ld
 * @brief    GNU Linker Script for Cortex-M based device
 * @version  V2.0.0
 * @date     21. May 2019
 ******************************************************************************/
/*
 * Copyright (c) 2009-2019 Arm Limited. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the License); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an AS IS BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * With quite a lot of changes by rdiez.
 */

OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)

MEMORY
{
  FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 256K
  RAM   (rwx) : ORIGIN = 0x20000000, LENGTH =  64K
}

SECTIONS
{
  .text :
  {
    /* This segment must be 4-byte aligned as defined in ARM ELF File Format specification. */
    . = ALIGN(4);
    _sfixed = .;

    KEEP(*(.vectors .vectors.*))
    *(.text .text.* .gnu.linkonce.t.*)  /* All ".gnu.linkonce" sections are used for C++ "vague linkage" */
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
    KEEP(*(.preinit_array))
    __preinit_array_end = .;

    . = ALIGN(4);
    /* We are not using .ctors/.dtors, but the alternative .init_array/.fini_array.
       Unfortunately, I haven't found out yet how to check in the application's
       source code wheter INIT_SECTION_ASM_OP is defined, to be sure. */
    __init_array_start = .;
    /* If you use "__attribute__ ((constructor (200)))", GCC generates a name like ".init_array.00200".
       Alternatively, you can use SORT_BY_INIT_PRIORITY, but with the naming scheme that GCC uses,
       the results would be the same. */
    KEEP(*(SORT(.init_array.*)))
    /* Objects with a priority are constructed before objects without priority. */
    KEEP(*(.init_array))
    __init_array_end = .;

    . = ALIGN(4);
    __fini_array_start = .;
    /* .fini_array must be sorted the same as .init_array. The C code will process it from bottom to top,
       so that the destruction order is the reverse of the construction order. */
    KEEP(*(SORT(.fini_array.*)))
    KEEP(*(.fini_array))
    __fini_array_end = .;

    KEEP(*(.eh_frame*))
  } > FLASH

  /* This is the exception index table. It is mainly needed for C++ exception support. Option "-funwind-tables"
     also generates these tables, which are useful if your C code wants to print a stack backtrace.
     The whole .ARM.exidx group is sorted by the linker, and I think duplicates are also collapsed together,
     so has to go in its own output section. */
  __exidx_start = .;  /* libgcc references __exidx_start and __exidx_end, but that seems to be specific to the ARM architecture. */
  .ARM.exidx :
  {
    *(.ARM.exidx* .gnu.linkonce.armexidx.*)
  } > FLASH
  __exidx_end = .;


  . = ALIGN(4);
  __etext = .;
  /* At the end of the ROM/Flash area, after __etext, lies the data that will be relocated to RAM
     on start-up, see .relocate below. */


  /* Place the stack at the beginning of some hardware RAM barrier. This way, a stack overflow will immediately
     crash the application, instead of corrupting data and making troubleshooting harder. */

  StackAlignment = 8;  /* Must be at least 4. There is an optional flag in the Cortex-M3 core to reduce alignment from 8 to 4,
                          so I think that 8 is a good choice here. */
  . = ORIGIN( RAM );

  .stackArea ALIGN( StackAlignment ) (NOLOAD):
  {
      __StackLimit = .;
      KEEP(*(.placeInStackArea))
      __StackTop = .;
  } > RAM


  /* After some time working on linker script files, you develop acute paranoia.
     Therefore, check that the stack values look plausible. */
  StackAssert1 = ASSERT( SIZEOF(.stackArea) >=  1 * 1024, "Stack area too small.");
  StackAssert2 = ASSERT( SIZEOF(.stackArea) <= 50 * 1024, "Stack area too big.");
  StackAssert3 = ASSERT( __StackTop > __StackLimit, "Wrong stack area address.");


  /**
   * Location counter can end up 2-byte aligned with narrow Thumb code but
   * __etext is assumed by startup code to be the LMA of a section in RAM
   * which must be 4-byte aligned
   */
  .relocate : AT (__etext)
  {
    . = ALIGN(4);
    __data_start__ = .;

    *(.data)
    *(.data.*)

    . = ALIGN(4);
    __data_end__ = .;
  } > RAM

  /* .bss section which is used for uninitialized data */
  .bss ALIGN(4) (NOLOAD) :
  {
    __bss_start__ = .;
    *(.bss)
    *(.bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end__ = .;
  } > RAM


  . = ALIGN(8);
  __end__ = . ;  /* Symbol __end__ marks the start of the malloc heap. */
  __HeapLimit = ORIGIN(RAM) + LENGTH(RAM);


  /* Account for all debug sections. This is only necessary if you use ldd's option --orphan-handling=warn .
     The sections name were copied from binutil's 2.43.1 file ld/ldscripts/armelf.x . */
  /* Stabs debugging sections.  */
  .stab          0 : { *(.stab) }
  .stabstr       0 : { *(.stabstr) }
  .stab.excl     0 : { *(.stab.excl) }
  .stab.exclstr  0 : { *(.stab.exclstr) }
  .stab.index    0 : { *(.stab.index) }
  .stab.indexstr 0 : { *(.stab.indexstr) }
  .comment 0 (INFO) : { *(.comment); LINKER_VERSION; }
  .gnu.build.attributes : { *(.gnu.build.attributes .gnu.build.attributes.*) }
  /* DWARF debug sections.
     Symbols in the DWARF debugging sections are relative to the beginning
     of the section so we begin them at 0.  */
  /* DWARF 1.  */
  .debug          0 : { *(.debug) }
  .line           0 : { *(.line) }
  /* GNU DWARF 1 extensions.  */
  .debug_srcinfo  0 : { *(.debug_srcinfo) }
  .debug_sfnames  0 : { *(.debug_sfnames) }
  /* DWARF 1.1 and DWARF 2.  */
  .debug_aranges  0 : { *(.debug_aranges) }
  .debug_pubnames 0 : { *(.debug_pubnames) }
  /* DWARF 2.  */
  .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
  .debug_abbrev   0 : { *(.debug_abbrev) }
  .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end) }
  .debug_frame    0 : { *(.debug_frame) }
  .debug_str      0 : { *(.debug_str) }
  .debug_loc      0 : { *(.debug_loc) }
  .debug_macinfo  0 : { *(.debug_macinfo) }
  /* SGI/MIPS DWARF 2 extensions.  */
  .debug_weaknames 0 : { *(.debug_weaknames) }
  .debug_funcnames 0 : { *(.debug_funcnames) }
  .debug_typenames 0 : { *(.debug_typenames) }
  .debug_varnames  0 : { *(.debug_varnames) }
  /* DWARF 3.  */
  .debug_pubtypes 0 : { *(.debug_pubtypes) }
  .debug_ranges   0 : { *(.debug_ranges) }
  /* DWARF 5.  */
  .debug_addr     0 : { *(.debug_addr) }
  .debug_line_str 0 : { *(.debug_line_str) }
  .debug_loclists 0 : { *(.debug_loclists) }
  .debug_macro    0 : { *(.debug_macro) }
  .debug_names    0 : { *(.debug_names) }
  .debug_rnglists 0 : { *(.debug_rnglists) }
  .debug_str_offsets 0 : { *(.debug_str_offsets) }
  .debug_sup      0 : { *(.debug_sup) }
  .ARM.attributes 0 : { KEEP (*(.ARM.attributes)) KEEP (*(.gnu.attributes)) }
  .note.gnu.arm.ident 0 : { KEEP (*(.note.gnu.arm.ident)) }
}

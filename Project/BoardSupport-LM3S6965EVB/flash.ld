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
 * With some changes by rdiez in 2021.
 */

OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)

MEMORY
{
  FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 256K
  RAM   (rwx) : ORIGIN = 0x20000000, LENGTH =  64K
}

ENTRY(Reset_Handler)

SECTIONS
{
  .text :
  {
    _sfixed = .;

    KEEP(*(.vectors))
    *(.text*)

    *(.ARM.extab* .gnu.linkonce.armextab.*)

    KEEP(*(.init))
    KEEP(*(.fini))

    /* We are not using .ctors/.dtors, but the alternative .init_array/.fini_array.
       Unfortunately, I haven't found out yet how to check in the application's
       source code wheter INIT_SECTION_ASM_OP is defined, to be sure. */
    *crtbegin.o(.ctors)
    *crtbegin?.o(.ctors)
    *(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors)
    *(SORT(.ctors.*))
    *(.ctors)

    *crtbegin.o(.dtors)
    *crtbegin?.o(.dtors)
    *(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)
    *(SORT(.dtors.*))
    *(.dtors)

    . = ALIGN(4);
    __preinit_array_start = .;
    KEEP(*(.preinit_array))
    __preinit_array_end = .;

    . = ALIGN(4);
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

    *(.rodata*)

    KEEP(*(.eh_frame*))
  } > FLASH

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
   * Location counter can end up 2byte aligned with narrow Thumb code but
   * __etext is assumed by startup code to be the LMA of a section in RAM
   * which must be 4byte aligned 
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

  .bss :
  {
    . = ALIGN(4);
    __bss_start__ = .;
    *(.bss)
    *(.bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end__ = .;
  } > RAM


  . = ALIGN(8);
  __end__ = .;   /* Symbol __end__ marks the start of the malloc heap. */
  __HeapLimit = ORIGIN(RAM) + LENGTH(RAM);
}

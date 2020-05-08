
// Copyright (C) 2012 R. Diez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the Affero GNU General Public License version 3
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// Affero GNU General Public License version 3 for more details.
//
// You should have received a copy of the Affero GNU General Public License version 3
// along with this program. If not, see http://www.gnu.org/licenses/ .

#include <stdint.h>

#include <BareMetalSupport/BoardInitUtils.h>
#include <BareMetalSupport/LinkScriptSymbols.h>
#include <BareMetalSupport/AssertionUtils.h>

#include <BoardSupport-LM3S6965EVB/ExceptionHandlers.h>

#ifndef __ARM_FEATURE_UNALIGNED
  #error "You should specify GCC switch -munaligned-access"
#endif


extern "C" void __libc_init_array ( void );  // Provided by some GCC library.

extern "C" void BareMetalSupport_Reset_Handler ( void )
{
  InitDataSegments();

  // Initialize the C/C++ support by calling all registered constructors.
  __libc_init_array();

  // From this point on, all C/C++ support has been initialised, and the user code can run.

  RunUserCode();

  // If you want to check for memory leaks and so on, you may need to call the destructors here:
  //   __libc_fini_array();

  Panic("RunUserCode() returned unexpectedly.");
}


__attribute__ ((section(".vectors"),used))
static const void * ExceptionTable[] =
{
  /* Configure Initial Stack Pointer, using linker-generated symbols */
  &__StackTop,
  (void *) BareMetalSupport_Reset_Handler,

  (void *) NMI_Handler,
  (void *) HardFault_Handler,
  (void *) MemManage_Handler,
  (void *) BusFault_Handler,
  (void *) UsageFault_Handler,
  (void *) 0,  // Reserved.
  (void *) 0,  // Reserved.
  (void *) 0,  // Reserved.
  (void *) 0,  // Reserved.
  (void *) SVC_Handler,
  (void *) DebugMon_Handler,
  (void *) 0,  // Reserved.
  (void *) PendSV_Handler,
  (void *) SysTick_Handler,
};

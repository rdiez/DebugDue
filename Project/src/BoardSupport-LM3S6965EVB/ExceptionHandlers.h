
#pragma once

extern "C" void NMI_Handler        ( void );
extern "C" void HardFault_Handler  ( void );
extern "C" void MemManage_Handler  ( void );
extern "C" void BusFault_Handler   ( void );
extern "C" void UsageFault_Handler ( void );
extern "C" void SVC_Handler        ( void );
extern "C" void DebugMon_Handler   ( void );
extern "C" void PendSV_Handler     ( void );
extern "C" void SysTick_Handler    ( void );

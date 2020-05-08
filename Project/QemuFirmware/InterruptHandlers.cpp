
#include <BoardSupport-LM3S6965EVB/ExceptionHandlers.h>

#include <BareMetalSupport/AssertionUtils.h>


extern "C" void __halt();

void __halt()
{
  Panic( "Unexpected interrupt." );
}


void NMI_Handler        (void) __attribute__ ((weak, alias("__halt")));
void HardFault_Handler  (void) __attribute__ ((weak, alias("__halt")));
void MemManage_Handler  (void) __attribute__ ((weak, alias("__halt")));
void BusFault_Handler   (void) __attribute__ ((weak, alias("__halt")));
void UsageFault_Handler (void) __attribute__ ((weak, alias("__halt")));
void SVC_Handler        (void) __attribute__ ((weak, alias("__halt")));
void DebugMon_Handler   (void) __attribute__ ((weak, alias("__halt")));
void PendSV_Handler     (void) __attribute__ ((weak, alias("__halt")));
void SysTick_Handler    (void) __attribute__ ((weak, alias("__halt")));

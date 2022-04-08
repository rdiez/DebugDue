

#include <sam3xa.h>  // All interrupt handlers must probably be extern "C", so include their declarations here.

#include <Misc/AssertionUtils.h>


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
void DebugMon_Handler   (void) __attribute__ ((weak, alias("__halt")));

void SysTick_Handler    (void) __attribute__ ((weak, alias("__halt")));

void PIOA_Handler       (void) __attribute__ ((weak, alias("__halt")));
void PIOB_Handler       (void) __attribute__ ((weak, alias("__halt")));
void PIOC_Handler       (void) __attribute__ ((weak, alias("__halt")));
void PIOD_Handler       (void) __attribute__ ((weak, alias("__halt")));

void USART0_Handler     (void) __attribute__ ((weak, alias("__halt")));
void USART1_Handler     (void) __attribute__ ((weak, alias("__halt")));
void USART2_Handler     (void) __attribute__ ((weak, alias("__halt")));
void USART3_Handler     (void) __attribute__ ((weak, alias("__halt")));

void PWM_Handler        (void) __attribute__ ((weak, alias("__halt")));
void ADC_Handler        (void) __attribute__ ((weak, alias("__halt")));
void DACC_Handler       (void) __attribute__ ((weak, alias("__halt")));
void DMAC_Handler       (void) __attribute__ ((weak, alias("__halt")));
void UOTGHS_Handler     (void) __attribute__ ((weak, alias("__halt")));
void TRNG_Handler       (void) __attribute__ ((weak, alias("__halt")));

void TC0_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC1_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC2_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC3_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC4_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC5_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC6_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC7_Handler        (void) __attribute__ ((weak, alias("__halt")));
void TC8_Handler        (void) __attribute__ ((weak, alias("__halt")));

void EFC0_Handler       (void) __attribute__ ((weak, alias("__halt")));
void EFC1_Handler       (void) __attribute__ ((weak, alias("__halt")));

void HSMCI_Handler      (void) __attribute__ ((weak, alias("__halt")));
void TWI0_Handler       (void) __attribute__ ((weak, alias("__halt")));
void TWI1_Handler       (void) __attribute__ ((weak, alias("__halt")));
void SPI0_Handler       (void) __attribute__ ((weak, alias("__halt")));
void SSC_Handler        (void) __attribute__ ((weak, alias("__halt")));

void SMC_Handler        (void) __attribute__ ((weak, alias("__halt")));
void EMAC_Handler       (void) __attribute__ ((weak, alias("__halt")));

void RTC_Handler        (void) __attribute__ ((weak, alias("__halt")));
void RTT_Handler        (void) __attribute__ ((weak, alias("__halt")));
void RSTC_Handler       (void) __attribute__ ((weak, alias("__halt")));
void PMC_Handler        (void) __attribute__ ((weak, alias("__halt")));
void SUPC_Handler       (void) __attribute__ ((weak, alias("__halt")));
void WDT_Handler        (void) __attribute__ ((weak, alias("__halt")));

void CAN0_Handler       (void) __attribute__ ((weak, alias("__halt")));
void CAN1_Handler       (void) __attribute__ ((weak, alias("__halt")));

void SVC_Handler        (void) __attribute__ ((weak, alias("__halt")));
void PendSV_Handler     (void) __attribute__ ((weak, alias("__halt")));


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


#include <BareMetalSupport/BoardInitUtils.h>

#include <assert.h>

#include <sam3xa.h>

#include <BareMetalSupport/BusyWait.h>
#include <BareMetalSupport/IoUtils.h>
#include <BareMetalSupport/AssertionUtils.h>

#ifndef __ARM_FEATURE_UNALIGNED
  #error "You should specify GCC switch -munaligned-access"
#endif

// These symbols are defined in the linker script file.
extern "C" int _sfixed;
extern "C" int _efixed;
extern "C" int _etext;
extern "C" int _srelocate;
extern "C" int _erelocate;
extern "C" int _szero;
extern "C" int _ezero;
extern "C" int _estack;


static void SetupCpuClock ( void )
{
    // WARNING: This routine is called very early after a reset, so things
    // like the .data and .bss segments have probably not been initialised yet.

    // NOTE about JTAG debugging:
    //   You may have trouble connecting with a JTAG debugger before the clock
    //   has been setup. After a hardware reset, the core runs at 4 MHz by default.
    //   This routine switches to a 12 MHz clock (or 6 MHz after a soft reset), and
    //   then to the final 84 MHz. Even if your debugger can slow the JTAG clock down,
    //   I am not sure that the JTAG connection will always survive the clock changes.


    // Set the FWS (Flash Wait State in the Flash Mode Register) for both flash banks:
    // - FAM: Flash Access Mode: 0: 128-bit access in read Mode only, enhances access speed at the cost of power consumption.
    // - FRDY: Ready Interrupt Enable: 0: Flash Ready does not generate an interrupt.
    // - FWS: Flash Wait State: 4 + 1 = 5 wait states. See also constant CHIP_FREQ_FWS_3.
    //   The core will run at 84 MHz, and the CPU's VDDCORE pins are tied on the Arduino Due
    //   to signal VDDOUT -> VDDPLL. VDDIN has 3.3V, but I could not find any information on
    //   how to program the embedded Power Regulator.
    //   According to the data sheet, section "Embedded Flash Characteristics", if we run
    //   the CPU core at 84 MHz with VDDCORE set to 1.80 V, then we need 5 wait states,
    //   which matches our setting. However, should VDDCORE be 1.62 V, we are out of spec.
    EFC0->EEFC_FMR = EEFC_FMR_FWS(4);
    EFC1->EEFC_FMR = EEFC_FMR_FWS(4);


    const uint32_t SYS_BOARD_OSCOUNT = CKGR_MOR_MOSCXTST( 0x8 );   // Start-up time in Slow Clock cycles (multiplied by 8).
    const uint32_t SYS_CKGR_MOR_KEY_VALUE = CKGR_MOR_KEY( 0x37 );  // Key to unlock MOR register.

    // If the crystal oscillator has not already been selected into the Main Clock,
    // assume that it has not been enabled and stabilised yet, so do it here.

    if ( !( PMC->CKGR_MOR & CKGR_MOR_MOSCSEL ) )
    {
        PMC->CKGR_MOR = SYS_CKGR_MOR_KEY_VALUE |
                        SYS_BOARD_OSCOUNT |
                        CKGR_MOR_MOSCRCEN |  // Main On-Chip RC Oscillator Enable. This is probably the on-chip fast RC oscillator.
                                             // After a hardware reset we are running on it, so it probably must be kept enabled
                                             // until we are finished configuring the clocks.
                        CKGR_MOR_MOSCXTEN;   // Main Crystal Oscillator Enable.

        //  Wail until the PMC Status Register reports that the main XTAL oscillator is stabilised.
        while ( !(PMC->PMC_SR & PMC_SR_MOSCXTS) )
        {
        }
    }

    // Switch the Main Clock to the crystal oscillator. By default after a hardware reset, the on-chip fast RC oscillator runs at 4 MHz,
    // and the crystal oscillator on the Arduino Due runs at 12 MHz. So we are running the CPU faster here,
    // assuming we came here after a hardware reset.
    PMC->CKGR_MOR = SYS_CKGR_MOR_KEY_VALUE |
                    SYS_BOARD_OSCOUNT |
                    CKGR_MOR_MOSCRCEN |
                    CKGR_MOR_MOSCXTEN |
                    CKGR_MOR_MOSCSEL;

    // Wail until the PMC Status Register reports that the switch is complete.
    while (!(PMC->PMC_SR & PMC_SR_MOSCSELS))
    {
    }

    // Switch the Master Clock to the Main Clock, leaving other clock settings unchanged.
    // If we were on the PLL clock, remember that we cannot change the clock source and
    // the prescaler factor at the same time, so the resulting speed may be 12 MHz / 2 = 6 MHz for a short time.
    const uint32_t prevPmcMckr = PMC->PMC_MCKR;
    // - After a hard reset, prevPmcMckr is 1, which means that the Main Clock is selected, as expected.
    // - After a GDB 'load' command (which does a kind of soft reset), the value is 18 (0b10010),
    //   meaning that the PLLA clock divided by 2 was selected (which is what this routine does at the end).
    PMC->PMC_MCKR = (prevPmcMckr & ~uint32_t(PMC_MCKR_CSS_Msk) ) | PMC_MCKR_CSS_MAIN_CLK;

    // Wail until the PMC Status Register reports that the Master Clock is ready.
    while ( !(PMC->PMC_SR & PMC_SR_MCKRDY) )
    {
    }

    // Generate a fast clock with the PLL by setting the PLLA Register in the PMC Clock Generator.
    PMC->CKGR_PLLAR = CKGR_PLLAR_ONE |  // Always 1.
                      CKGR_PLLAR_MULA(0xdUL) |  // Multiplier is 0xd + 1 = 0xe (14). The crystal oscillator freq. is 12 MHz,
                                                // so the resulting frequency is 12 MHz x 14 = 168 MHz (84 MHz x 2).
                      CKGR_PLLAR_PLLACOUNT(0x3fUL) |   // Some delay used during the switching.
                      CKGR_PLLAR_DIVA(0x1UL);   // 1 = The divider is bypassed.

    // Wail until the PMC Status Register reports that the PLL is locked.
    while ( !(PMC->PMC_SR & PMC_SR_LOCKA) )
    {
    }


    // We cannot switch directly to the PLL / 2 clock, we must set the prescaler factor first.
    const uint32_t PLL_FACTOR = PMC_MCKR_PRES_CLK_2;  // 168 MHz / prescaler of 2 = our target core frequency of 84 MHz.

    PMC->PMC_MCKR = PLL_FACTOR | PMC_MCKR_CSS_MAIN_CLK;

    // Wail until the PMC Status Register reports that the Master Clock is ready.
    while ( !(PMC->PMC_SR & PMC_SR_MCKRDY) )
    {
    }


    // Switch the Master Clock to the PLLA / 2 clock.
    PMC->PMC_MCKR = PLL_FACTOR | PMC_MCKR_CSS_PLLA_CLK;

    // Wail until the PMC Status Register reports that the Master Clock is ready.
    while (!(PMC->PMC_SR & PMC_SR_MCKRDY))
    {
    }


    // You can check the Main Clock frequency by reading the CKGR_MCFR register like this:
    //   const uint16_t measuredMainClockFreqIn16SlowClockCycles = PMC->CKGR_MCFR & CKGR_MCFR_MAINF_Msk;
    // On the Arduino Due, the crystal oscillator freq. is 12 MHz, and the Slow Clock runs at 32 KHz,
    // that would be 375 Main Clock ticks for every Slow Clock tick.
    // In 16 Slow Clock ticks, we have 6000 Main Clock ticks then. On my board, the value read
    // is 6601, which is around 10 % off.
}


extern "C" void __libc_init_array ( void );  // Provided by some GCC library.

extern "C" void BareMetalSupport_Reset_Handler ( void )
{
    SetupCpuClock();

    // Delay the start-up sequence, so that an external JTAG debugger has a chance
    // to stop the firmware near the beginning.
    //
    // How much busy wait time you need to spend here depends on how fast your JTAG adapter is.
    // With my slow Bus Pirate (at 'normal' speed, instead of 'fast'), and with a non-optimised
    // JtagDue firmware, I need around 34 ms. If you have a fast JTAG probe, you can probably
    // lower this time in order to get faster overall boot times.
    // When using a second Arduino Due, we need more time. 110 ms seems enough.
    //
    // If you do not need to debug the firmware from the very beginning, or if you do not place
    // breakpoints somewhere during the initialisation code, then you can disable this busy wait.
    if ( true )
    {
      const unsigned BUSY_WAIT_LOOP_US = 120 * 1000;
      BusyWaitLoop( GetBusyWaitLoopIterationCountFromUs( BUSY_WAIT_LOOP_US ) );
    }


    // Relocate the initialised data from flash to SRAM.

    const uint32_t * relocSrc  = (const uint32_t *)&_etext;
          uint32_t * relocDest = (      uint32_t *)&_srelocate;

    if ( relocSrc != relocDest )
    {
        while ( relocDest < (const uint32_t *) &_erelocate )
        {
            *relocDest++ = *relocSrc++;
        }
    }


    // Clear the zero segment (BSS).

    for ( uint32_t * zeroSegPtr = (uint32_t *)&_szero;  zeroSegPtr < (const uint32_t *) &_ezero;  ++zeroSegPtr )
    {
      *zeroSegPtr = 0;
    }


    // Set the vector table base address.
    const uint32_t * const pVecSrc = (const uint32_t *) & _sfixed;
    SCB->VTOR = ((uint32_t) pVecSrc & SCB_VTOR_TBLOFF_Msk);

    if (((uint32_t) pVecSrc >= IRAM0_ADDR) && ((uint32_t) pVecSrc < NFC_RAM_ADDR))
    {
        SCB->VTOR |= (1UL) << SCB_VTOR_TBLBASE_Pos;
    }


    // The CPU starts at 4 MHz, and that should be the default value of variable SystemCoreClock.
    // We have set the CPU clock above, so update this variable here. Its value is needed
    // in order to calculate the clock delay to get the correct UART speed.

    assert( SystemCoreClock == 4000000 );

    SystemCoreClockUpdate();

    #ifndef NDEBUG
      assert( SystemCoreClock == CPU_CLOCK );
      assert( SystemCoreClock == CHIP_FREQ_CPU_MAX );
    #endif


    // Initialize the C/C++ support by calling all registered constructors.
    __libc_init_array();

    // From this point on, all C/C++ support has been initialised, and the user code can run.

    RunUserCode();

    // If you want to check for memory leaks and so on, you may need to call the destructors here:
    //   __libc_fini_array();

    Panic("RunUserCode() returned unexpectedly.");
}


// This exception table (vector table) implementation has been copied from file startup_sam3xa.c,
// and then slightly modified to call our 'BareMetalSupport_Reset_Handler' entry point.

__attribute__ ((section(".vectors"),used))
static const DeviceVectors ExceptionTable =
{
	/* Configure Initial Stack Pointer, using linker-generated symbols */
	(void*) (&_estack),
	(void*) BareMetalSupport_Reset_Handler,

	(void*) NMI_Handler,
	(void*) HardFault_Handler,
	(void*) MemManage_Handler,
	(void*) BusFault_Handler,
	(void*) UsageFault_Handler,
	(void*) (0UL),           /* Reserved */
	(void*) (0UL),           /* Reserved */
	(void*) (0UL),           /* Reserved */
	(void*) (0UL),           /* Reserved */
	(void*) SVC_Handler,
	(void*) DebugMon_Handler,
	(void*) (0UL),           /* Reserved */
	(void*) PendSV_Handler,
	(void*) SysTick_Handler,

	/* Configurable interrupts */
	(void*) SUPC_Handler,    /*  0  Supply Controller */
	(void*) RSTC_Handler,    /*  1  Reset Controller */
	(void*) RTC_Handler,     /*  2  Real Time Clock */
	(void*) RTT_Handler,     /*  3  Real Time Timer */
	(void*) WDT_Handler,     /*  4  Watchdog Timer */
	(void*) PMC_Handler,     /*  5  PMC */
	(void*) EFC0_Handler,    /*  6  EFC 0 */
	(void*) EFC1_Handler,    /*  7  EFC 1 */
	(void*) UART_Handler,    /*  8  UART */
#ifdef _SAM3XA_SMC_INSTANCE_
	(void*) SMC_Handler,     /*  9  SMC */
#else
	(void*) (0UL),           /*  9 Reserved */
#endif /* _SAM3XA_SMC_INSTANCE_ */
#ifdef _SAM3XA_SDRAMC_INSTANCE_
	(void*) SDRAMC_Handler,  /* 10  SDRAMC */
#else
	(void*) (0UL),           /* 10 Reserved */
#endif /* _SAM3XA_SDRAMC_INSTANCE_ */
	(void*) PIOA_Handler,    /* 11 Parallel IO Controller A */
	(void*) PIOB_Handler,    /* 12 Parallel IO Controller B */
#ifdef _SAM3XA_PIOC_INSTANCE_
	(void*) PIOC_Handler,    /* 13 Parallel IO Controller C */
#else
	(void*) (0UL),           /* 13 Reserved */
#endif /* _SAM3XA_PIOC_INSTANCE_ */
#ifdef _SAM3XA_PIOD_INSTANCE_
	(void*) PIOD_Handler,    /* 14 Parallel IO Controller D */
#else
	(void*) (0UL),           /* 14 Reserved */
#endif /* _SAM3XA_PIOD_INSTANCE_ */
#ifdef _SAM3XA_PIOE_INSTANCE_
	(void*) PIOE_Handler,    /* 15 Parallel IO Controller E */
#else
	(void*) (0UL),           /* 15 Reserved */
#endif /* _SAM3XA_PIOE_INSTANCE_ */
#ifdef _SAM3XA_PIOF_INSTANCE_
	(void*) PIOF_Handler,    /* 16 Parallel IO Controller F */
#else
	(void*) (0UL),           /* 16 Reserved */
#endif /* _SAM3XA_PIOF_INSTANCE_ */
	(void*) USART0_Handler,  /* 17 USART 0 */
	(void*) USART1_Handler,  /* 18 USART 1 */
	(void*) USART2_Handler,  /* 19 USART 2 */
#ifdef _SAM3XA_USART3_INSTANCE_
	(void*) USART3_Handler,  /* 20 USART 3 */
#else
	(void*) (0UL),           /* 20 Reserved */
#endif /* _SAM3XA_USART3_INSTANCE_ */
	(void*) HSMCI_Handler,   /* 21 MCI */
	(void*) TWI0_Handler,    /* 22 TWI 0 */
	(void*) TWI1_Handler,    /* 23 TWI 1 */
	(void*) SPI0_Handler,    /* 24 SPI 0 */
#ifdef _SAM3XA_SPI1_INSTANCE_
	(void*) SPI1_Handler,    /* 25 SPI 1 */
#else
	(void*) (0UL),           /* 25 Reserved */
#endif /* _SAM3XA_SPI1_INSTANCE_ */
	(void*) SSC_Handler,     /* 26 SSC */
	(void*) TC0_Handler,     /* 27 Timer Counter 0 */
	(void*) TC1_Handler,     /* 28 Timer Counter 1 */
	(void*) TC2_Handler,     /* 29 Timer Counter 2 */
	(void*) TC3_Handler,     /* 30 Timer Counter 3 */
	(void*) TC4_Handler,     /* 31 Timer Counter 4 */
	(void*) TC5_Handler,     /* 32 Timer Counter 5 */
#ifdef _SAM3XA_TC2_INSTANCE_
	(void*) TC6_Handler,     /* 33 Timer Counter 6 */
	(void*) TC7_Handler,     /* 34 Timer Counter 7 */
	(void*) TC8_Handler,     /* 35 Timer Counter 8 */
#else
	(void*) (0UL),           /* 33 Reserved */
	(void*) (0UL),           /* 34 Reserved */
	(void*) (0UL),           /* 35 Reserved */
#endif /* _SAM3XA_TC2_INSTANCE_ */
	(void*) PWM_Handler,     /* 36 PWM */
	(void*) ADC_Handler,     /* 37 ADC controller */
	(void*) DACC_Handler,    /* 38 DAC controller */
	(void*) DMAC_Handler,    /* 39 DMA Controller */
	(void*) UOTGHS_Handler,  /* 40 USB OTG High Speed */
	(void*) TRNG_Handler,    /* 41 True Random Number Generator */
#ifdef _SAM3XA_EMAC_INSTANCE_
	(void*) EMAC_Handler,    /* 42 Ethernet MAC */
#else
	(void*) (0UL),           /* 42 Reserved */
#endif /* _SAM3XA_EMAC_INSTANCE_ */
	(void*) CAN0_Handler,    /* 43 CAN Controller 0 */
	(void*) CAN1_Handler    /* 44 CAN Controller 1 */
};

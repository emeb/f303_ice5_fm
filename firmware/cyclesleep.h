/*
 * cyclesleep.h - zyp's cycle counter sleep routines
 * 12-20-12 E. Brombaugh
 * 03-20-17 E. Brombaugh - fixed bugs, updated to use CMSIS DWT defs
 */

#ifndef __cyclesleep__
#define __cyclesleep__

#include "stm32f30x.h"

void cyccnt_enable(void);
void cyclesleep(uint32_t cycles);
uint32_t cyclegoal(uint32_t cycles);
uint32_t cyclegoal_ms(uint32_t ms);
uint32_t cyclecheck(uint32_t goal);
void delay(uint32_t ms);
void start_meas(void);
void end_meas(void);
void get_meas(uint32_t *act, uint32_t *tot);

#endif

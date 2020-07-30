/*
 * cyclesleep.c - zyp's cycle counter sleep routines
 * 12-20-12 E. Brombaugh
 * 03-20-17 E. Brombaugh - fixed bugs, updated to use CMSIS DWT defs
 */
 
#include "cyclesleep.h"

uint32_t DelayCyc1s; 
uint32_t s_tot, act_cyc, tot_cyc;

/*
 * get sysclock freq
 */
uint32_t get_sysclk(void)
{
	RCC_ClocksTypeDef RCC_Clocks;
	
	/* Compute Delay amount */
	RCC_GetClocksFreq(&RCC_Clocks);
	return RCC_Clocks.SYSCLK_Frequency;
}

/*
 * turn on cycle counter
 */
void cyccnt_enable(void)
{
    CoreDebug->DEMCR |=  CoreDebug_DEMCR_TRCENA_Msk;
    DWT->CTRL |=  DWT_CTRL_CYCCNTENA_Msk;
	DelayCyc1s = get_sysclk();
}

/*
 * compute goal for cycle counter based on desired delay in cycles
 */
uint32_t cyclegoal(uint32_t cycles)
{
	return cycles + DWT->CYCCNT;
}

/*
 * compute goal for cycle counter based on desired delay in milliseconds
 */
uint32_t cyclegoal_ms(uint32_t ms)
{
	return ms*(DelayCyc1s/1000) + DWT->CYCCNT;
}

/*
 * return TRUE if goal is reached
 */
uint32_t cyclecheck(uint32_t goal)
{
    /**************************************************/
    /* DANGER WILL ROBINSON!                          */
    /* the following syntax is CRUCIAL to ensuring    */
    /* that this test doesn't have a wrap bug         */
    /**************************************************/
	return (((int32_t)DWT->CYCCNT - (int32_t)goal) < 0);
}

/*
 * sleep for a certain number of cycles
 */
void cyclesleep(uint32_t cycles)
{
    uint32_t goal = cyclegoal(cycles);
    
    while(cyclecheck(goal));
}

/*
 * sleep for a certain number of milliseconds
 */
void delay(uint32_t ms)
{
	cyclesleep(ms*(DelayCyc1s/1000));
}

/*
 * called at start of routine to be measured
 */
void start_meas(void)
{
	/* grab current cycle count & measure total cycles */
	uint32_t curr_cyc = DWT->CYCCNT;
	tot_cyc = curr_cyc - s_tot;
	s_tot = curr_cyc;

}

/*
 * called at end of routine to be measured
 */
void end_meas(void)
{
	/* grab current cycle count and measure active cycles */
	uint32_t curr_cyc = DWT->CYCCNT;
	act_cyc = curr_cyc - s_tot;
}

/*
 * return the measurement results
 */
void get_meas(uint32_t *act, uint32_t *tot)
{
	*act = act_cyc;
	*tot = tot_cyc;
}

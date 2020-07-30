/*
	main.c
	
	Part of f303_ice5 - stm32f303 & ice5lp4k FPGA
	Copyright 07-02-2016 E. Brombaugh
*/
#include <stdio.h>
#include <stdlib.h>
#include "stm32f30x.h"
#include "cyclesleep.h"
#include "systick.h"
#include "usart.h"
#include "led.h"

#include "fm.h"
#include "cmd.h"

/*
 * start 
 */
int main(void)
{
	int rxchar;
	uint32_t delaygoal;
	uint16_t curr_sw, prev_sw = 0;
	
	/* start cycle counter */
	cyccnt_enable();
	
	/* init LEDs & Switches */
	SysTick_Init();
	LEDInit();
	
	/* Setup USART diag output */
	setup_usart1();
	printf("\nSTM32F303 ice5\n");
	
	/* Setup FM FPGA */
	FM_Init();
	printf("FM configured.\n");
	
	/* loop forever */
	init_cmd();
	delaygoal = cyclegoal_ms(100);
	while(1)
	{
		/* Blink the heartbeat LED */
		if(!cyclecheck(delaygoal))
		{
			LEDToggle();
			delaygoal = cyclegoal_ms(100);
		}
		
		/* Keypress */
		curr_sw = SysTick_GetSw();
		if(curr_sw != prev_sw)
		{
			FM_Gate(curr_sw);
			prev_sw = curr_sw;
			printf("Key = %d\n", curr_sw);
		}
		
		/* UART command processing */
		if((rxchar = get_usart())!= EOF)
		{
			/* Parse commands */
			cmd_parse(rxchar);
		}
	}
}

#ifdef  USE_FULL_ASSERT

/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t* file, uint32_t line)
{ 
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */

  /* Infinite loop */
  while (1)
  {
  }
}
#endif

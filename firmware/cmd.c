/*
 * cmd.c - Command parsing routines for STM32F303 breakout SPI to ice5 FPGA
 * 05-11-16 E. Brombaugh
 */
#include "stm32f30x.h"
#include "arm_math.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "arm_math.h"
#include "usart.h"
#include "cyclesleep.h"
#include "ice5.h"
#include "fm.h"

#define MAX_ARGS 4

/* locals we use here */
char cmd_buffer[256];
char *cmd_wptr;
const char *cmd_commands[] = 
{
	"help",
	"spi_read",
	"spi_write",
	"readbus",
	"readreg",
	"setvfreq",
	"setofreq",
	"setoatten",
	"setowave",
	""
};

/* reset buffer & display the prompt */
void cmd_prompt(void)
{
	/* reset input buffer */
	cmd_wptr = &cmd_buffer[0];

	/* prompt user */
	printf("\rCommand>");
}

/* process command line after <cr> */
void cmd_proc(void)
{
	char *token, *argv[MAX_ARGS];
	int argc, cmd, reg, voice;
	unsigned long data, p_data;
	float32_t freq;

	/* parse out three tokens: cmd arg arg */
	argc = 0;
	token = strtok(cmd_buffer, " ");
	while(token != NULL && argc < MAX_ARGS)
	{
		argv[argc++] = token;
		token = strtok(NULL, " ");
	}

	/* figure out which command it is */
	if(argc > 0)
	{
		cmd = 0;
		while(cmd_commands[cmd] != '\0')
		{
			if(strcmp(argv[0], cmd_commands[cmd])==0)
				break;
			cmd++;
		}
	
		/* Can we handle this? */
		if(cmd_commands[cmd] != '\0')
		{
			printf("\r\n");

			/* Handle commands */
			switch(cmd)
			{
				case 0:		/* Help */
					printf("help - this message\r\n");
					printf("spi_read <addr> - FPGA SPI read reg\r\n");
					printf("spi_write <addr> <data> - FPGA SPI write reg, data\r\n");
					printf("readbus - parse readbus diags\r\n");
					printf("readreg - dump param regs\r\n");
					printf("setvfreq <voice> <freq> - set voice freq (Hz)\r\n");
					printf("setofreq <voice> <op> <freq> - set op freq (ratio / -Hz)\r\n");
					printf("setoatten <voice> <op> <atten> - set op atten\r\n");
					printf("setowave <voice> <op> <wave> - set op wave\r\n");
					break;
	
				case 1: 	/* spi_read */
					if(argc < 2)
						printf("spi_read - missing arg(s)\r\n");
					else
					{
						reg = (int)strtoul(argv[1], NULL, 0) & 0x7f;
						ICE5_FPGA_Slave_Read(reg, &data);
						printf("spi_read: 0x%02X = 0x%08lX\r\n", reg, data);
					}
					break;
	
				case 2: 	/* spi_write */
					if(argc < 3)
						printf("spi_write - missing arg(s)\r\n");
					else
					{
						reg = (int)strtoul(argv[1], NULL, 0) & 0x7f;
						data = strtoul(argv[2], NULL, 0);
						ICE5_FPGA_Slave_Write(reg, data);
						printf("spi_write: 0x%02X 0x%08lX\r\n", reg, data);
					}
					break;
	
				case 3: 	/* readbus */
					ICE5_FPGA_Slave_Read(14, &data);
					printf("freq: 0x%05lX\r\n", data & 0x7FFFF);
					printf("  wv: 0x%01lX\r\n", data>>19 & 0x7);
					printf(" adj: 0x%03lX\r\n", data>>22 & 0x1FF);
					p_data = data>>31;
					ICE5_FPGA_Slave_Read(15, &data);
					printf("  ar: 0x%05lX\r\n", (data<<1 | p_data) & 0x3F);
					printf("  dr: 0x%05lX\r\n", data>>5 & 0x3F);
					printf("  sl: 0x%05lX\r\n", data>>11 & 0x1F);
					printf("  rr: 0x%05lX\r\n", data>>16 & 0x3F);
					printf("  li: 0x%01lX\r\n", data>>22 & 0x1);
					printf("  ri: 0x%01lX\r\n", data>>23 & 0x1);
					printf(" mod: 0x%01lX\r\n", data>>24 & 0x1);
					printf(" acc: 0x%01lX\r\n", data>>25 & 0x1);
					printf(" clr: 0x%01lX\r\n", data>>26 & 0x1);
					printf("  fb: 0x%01lX\r\n", data>>27 & 0x1);
					break;
	
				case 4: 	/* readreg */
					ICE5_FPGA_Slave_Read(2, &data);
					printf("freq: 0x%05lX\r\n", data & 0x7FFFF);
					ICE5_FPGA_Slave_Read(4, &data);
					printf("  wv: 0x%01lX\r\n", data & 0x7);
					ICE5_FPGA_Slave_Read(9, &data);
					printf(" adj: 0x%03lX\r\n", data & 0x1FF);
					ICE5_FPGA_Slave_Read(5, &data);
					printf("  ar: 0x%05lX\r\n", data & 0x3F);
					ICE5_FPGA_Slave_Read(6, &data);
					printf("  dr: 0x%05lX\r\n", data & 0x3F);
					ICE5_FPGA_Slave_Read(7, &data);
					printf("  sl: 0x%05lX\r\n", data & 0x1F);
					ICE5_FPGA_Slave_Read(8, &data);
					printf("  rr: 0x%05lX\r\n", data & 0x3F);
					ICE5_FPGA_Slave_Read(10, &data);
					printf("  li: 0x%01lX\r\n", data>>4 & 0x1);
					printf("  ri: 0x%01lX\r\n", data>>5 & 0x1);
					printf(" mod: 0x%01lX\r\n", data>>3 & 0x1);
					printf(" acc: 0x%01lX\r\n", data>>2 & 0x1);
					printf(" clr: 0x%01lX\r\n", data>>1 & 0x1);
					printf("  fb: 0x%01lX\r\n", data & 0x1);
					break;
	
				case 5: 	/* set voice frq */
					if(argc < 3)
						printf("setvfreq - missing arg(s)\r\n");
					else
					{
						voice = (int)strtoul(argv[1], NULL, 0) & 0x1;
						freq = strtof(argv[2], NULL);
						FM_SetVoicePatch(voice, &voices[voice], freq);
						//printf("setvfreq: %d %f\r\n", voice, freq);
						printf("OK\r\n");
					}
					break;
	
				case 6: 	/* set voice op frq */
					if(argc < 4)
						printf("setofreq - missing arg(s)\r\n");
					else
					{
						voice = (int)strtoul(argv[1], NULL, 0) & 0x1;
						reg = (int)strtoul(argv[2], NULL, 0) & 0x1;
						freq = strtof(argv[3], NULL);
						FM_SetVoiceOpFreq(&voices[voice], reg, freq);
						//printf("setofreq: %d %d %f\r\n", voice, reg, freq);
						printf("OK\r\n");
					}
					break;
	
				case 7: 	/* set voice op atten */
					if(argc < 4)
						printf("setoatten - missing arg(s)\r\n");
					else
					{
						voice = (int)strtoul(argv[1], NULL, 0) & 0x1;
						reg = (int)strtoul(argv[2], NULL, 0) & 0x7;
						data = strtoul(argv[3], NULL, 0) & 0x1ff;
						FM_SetVoiceOpAtten(&voices[voice], reg, data);
						printf("setoatten: %d %d %ld\r\n", voice, reg, data);
					}
					break;
	
				case 8: 	/* set voice op wave */
					if(argc < 4)
						printf("setowave - missing arg(s)\r\n");
					else
					{
						voice = (int)strtoul(argv[1], NULL, 0) & 0x1;
						reg = (int)strtoul(argv[2], NULL, 0) & 0x7;
						data = strtoul(argv[3], NULL, 0) & 0x7;
						FM_SetVoiceOpWave(&voices[voice], reg, data);
						printf("setowave: %d %d %ld\r\n", voice, reg, data);
					}
					break;
	
				default:	/* shouldn't get here */
					break;
			}
		}
		else
			printf("Unknown command\r\n");
	}
}
	
void init_cmd(void)
{
	/* just prompts for now */
	cmd_prompt();
}

void cmd_parse(char ch)
{
	/* accumulate chars until cr, handle backspace */
	if(ch == '\b')
	{
		/* check for buffer underflow */
		if(cmd_wptr - &cmd_buffer[0] > 0)
		{
			printf("\b \b");		/* Erase & backspace */
			cmd_wptr--;		/* remove previous char */
		}
	}
	else if(ch == '\r')
	{
		*cmd_wptr = '\0';	/* null terminate, no inc */
		cmd_proc();
		cmd_prompt();
	}
	else
	{
		/* check for buffer full (leave room for null) */
		if(cmd_wptr - &cmd_buffer[0] < 254)
		{
			*cmd_wptr++ = ch;	/* store to buffer */
			putc(ch, stdout);			/* echo */
		}
	}
	fflush(stdout);
}

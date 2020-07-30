/*
 * ice5.c - interface routines for STM32F303 breakout SPI to ice5 FPGA
 * 04-30-16 E. Brombaugh
 */
 
#ifndef __FM__
#define __FM__

#include "stm32f30x.h"
#include "arm_math.h"

#define FM_Fsample 48000.0F
#define FM_Freq_Bits 19
#define FM_Freq_Mask ((1<<FM_Freq_Bits)-1)
#define FM_Flag_FB_EN (1<<0)
#define FM_Flag_ACC_CL (1<<1)
#define FM_Flag_ACC_EN (1<<2)
#define FM_Flag_MOD_EN (1<<3)
#define FM_Flag_Left (1<<4)
#define FM_Flag_Right (1<<5)

typedef struct
{
	float32_t freq;		/* operator frequency (+fixed or -relative) */
	uint16_t atten;		/* operator attenuation 0 - 511 */
	uint8_t wave;		/* operator waveform  0 - 7 */
	uint8_t ar;			/* operator envelope attack rate 0-63 */
	uint8_t dr;			/* operator envelope decay rate 0-63 */
	uint8_t sl;			/* operator envelope sustain level 0-31 */
	uint8_t rr;			/* operator envelope release rate 0-63 */
	uint8_t flags;		/* operator flags */
} operator_struct;

typedef struct
{
	operator_struct ops[8];		/* array of operators */
} voice_struct;

extern voice_struct voices[2];

void FM_Init(void);
void FM_SetOperator(uint8_t opnum, operator_struct *op, float32_t base_freq);
void FM_SetVoiceOpFreq(voice_struct *vs, uint8_t opnum, float32_t freq);
void FM_SetVoiceOpAtten(voice_struct *vs, uint8_t opnum, uint16_t atten);
void FM_SetVoiceOpWave(voice_struct *vs, uint8_t opnum, uint8_t wave);

void FM_SetVoiceFreq(uint8_t voice_num, voice_struct *vs, float32_t base_freq);
void FM_SetVoicePatch(uint8_t voice_num, voice_struct *vs, float32_t base_freq);
void FM_Gate(uint16_t gate_word);

#endif

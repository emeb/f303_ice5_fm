/*
 * fm.c - fm driver routines for ICE5 8-op FM design
 * 06-11-16 E. Brombaugh
 */

#include <stdio.h>
#include "fm.h"
#include "ice5.h"

/* FPGA bitstream */
extern uint8_t _binary_bitmap_bin_start;
extern uint8_t _binary_bitmap_bin_end;

/* predefined voices */
const operator_struct test_voice_0[8] =
{
	// frq,atten,wv,ar,dr,sl,rr,flags
	{-2.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 0
	{-1.0F, 0,0,20,20,2,20,FM_Flag_Left|FM_Flag_MOD_EN},	// op 1
	{-4.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 2
	{-2.0F, 2,0,20,20,2,20,FM_Flag_Left|FM_Flag_MOD_EN},	// op 3
	{-6.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 4
	{-3.0F, 4,0,20,20,2,20,FM_Flag_Left|FM_Flag_MOD_EN},	// op 5
	{-8.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 6
	{-4.0F, 6,0,20,20,2,20,FM_Flag_Left|FM_Flag_MOD_EN}		// op 7
};
const operator_struct test_voice_1[8] =
{
	// frq,atten,wv,ar,dr,sl,rr,flags
	{-2.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 0
	{-1.0F,0,0,20,20,2,20, FM_Flag_Right|FM_Flag_MOD_EN},	// op 1
	{-4.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 2
	{-2.0F,2,0,20,20,2,20, FM_Flag_Right|FM_Flag_MOD_EN},	// op 3
	{-6.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 4
	{-3.0F,4,0,20,20,2,20, FM_Flag_Right|FM_Flag_MOD_EN},	// op 5
	{-8.0F,40,0,20,20,2,20,FM_Flag_ACC_CL|FM_Flag_ACC_EN},	// op 6
	{-4.0F,6,0,20,20,2,20, FM_Flag_Right|FM_Flag_MOD_EN}	// op 7
};

voice_struct voices[2];

/*
 * set up the FPGA
 */
void FM_Init(void)
{
	uint32_t bitmap_size = &_binary_bitmap_bin_end - &_binary_bitmap_bin_start;
	uint8_t result;
	uint32_t reg;
	
	/* ICE5 FPGA interface setup */
	ICE5_Init();
	printf("FM_Init: ice5 interface initialized\n");
	//printf("Bitstream start @ 0x%08x\n", (unsigned int)&_binary_bitmap_bin_start);
	//printf("Bitstream end   @ 0x%08x\n", (unsigned int)&_binary_bitmap_bin_end);
	//printf("Bitstream length = 0x%08x bytes\n", (unsigned int)bitmap_size);
	
	/* load bitstream */
	printf("FM_Init: Configuring %d bytes....", (unsigned int)bitmap_size);
	result = ICE5_FPGA_Config(&_binary_bitmap_bin_start, bitmap_size);
	if(!result)
		printf("Done\n");
	else
		printf("Error code %d\n", result);
	
	/* check id */
	ICE5_FPGA_Slave_Read(0, &reg);
	printf("FM_Init: ID = 0x%08x\n", (unsigned int)reg);
	
	/* set blink rate */
	ICE5_FPGA_Slave_Write(1, 1249);
	
	/* set up voice 0 */
	memcpy(&voices[0], &test_voice_0, sizeof(voice_struct));
	FM_SetVoicePatch(0, &voices[0], 100.0F);
	
	/* set up voice 1 */
	memcpy(&voices[1], &test_voice_1, sizeof(voice_struct));
	FM_SetVoicePatch(1, &voices[1], 1000.0F);	
}

/*
 * compute frequency
 */
uint32_t FM_CalcFreq(float32_t freq)
{
	return (uint32_t)((float32_t)(1<<FM_Freq_Bits) * (freq / FM_Fsample))&FM_Freq_Mask;
}

/*
 * setup an operator
 */
void FM_SetOperator(uint8_t opnum, operator_struct *op, float32_t base_freq)
{
	/* set freq */
	if(op->freq < 0.0F)
		/* negative freqs are relative to base */
		ICE5_FPGA_Slave_Write(2, FM_CalcFreq(-op->freq*base_freq));
	else
		/* positive freqs are absolute */
		ICE5_FPGA_Slave_Write(2, FM_CalcFreq(op->freq));
	
	/* set wave */
	ICE5_FPGA_Slave_Write(4, op->wave&0x7);
	
	/* Set ADSR */
	ICE5_FPGA_Slave_Write(5, op->ar&0x3F);
	ICE5_FPGA_Slave_Write(6, op->dr&0x3F);
	ICE5_FPGA_Slave_Write(7, op->sl&0x1F);
	ICE5_FPGA_Slave_Write(8, op->dr&0x3F);
	
	/* set atten */
	ICE5_FPGA_Slave_Write(9, op->atten&0x1FF);
	
	/* set routing flags */
	ICE5_FPGA_Slave_Write(10, op->flags&0x3F);
	
	/* set address */
	ICE5_FPGA_Slave_Write(11, opnum&0x7F);
	
	/* write strobe */
	ICE5_FPGA_Slave_Write(12, 1);
}

/*
 * set frequency param in an operator of a voice struct
 */
void FM_SetVoiceOpFreq(voice_struct *vs, uint8_t opnum, float32_t freq)
{
	vs->ops[opnum].freq = freq;
}

/*
 * set atten param in an operator of a voice struct
 */
void FM_SetVoiceOpAtten(voice_struct *vs, uint8_t opnum, uint16_t atten)
{
	vs->ops[opnum].atten = atten;
}

/*
 * set wave param in an operator of a voice struct
 */
void FM_SetVoiceOpWave(voice_struct *vs, uint8_t opnum, uint8_t wave)
{
	vs->ops[opnum].wave = wave;
}

/*
 * set voice freq but leave other params alone
 * note - doesn't work right because write strobe updats other params too.
 */
void FM_SetVoiceFreq(uint8_t voice_num, voice_struct *vs, float32_t base_freq)
{
	uint8_t i;
	
	/* loop over all ops in the voice */
	for(i=0;i<8;i++)
	{
		/* set freq */
		if(vs->ops[voice_num].freq < 0.0F)
			/* negative freqs are relative to base */
			ICE5_FPGA_Slave_Write(2, FM_CalcFreq(-vs->ops[voice_num].freq*base_freq));
		else
			/* positive freqs are absolute */
			ICE5_FPGA_Slave_Write(2, FM_CalcFreq(vs->ops[voice_num].freq));
		
		/* set address */
		ICE5_FPGA_Slave_Write(11, (voice_num*8 + i)&0x7F);
		
		/* write strobe */
		ICE5_FPGA_Slave_Write(12, 1);
	}
}

/*
 * setup a voice with a patch
 */
void FM_SetVoicePatch(uint8_t voice_num, voice_struct *vs, float32_t base_freq)
{
	uint8_t i;
	
	/* loop over all ops in the patch */
	for(i=0;i<8;i++)
	{
		FM_SetOperator(8*voice_num+i, &vs->ops[i], base_freq);
	}
}

/*
 * trigger voice(s)
 */
void FM_Gate(uint16_t gate_word)
{
	ICE5_FPGA_Slave_Write(3, gate_word);
}
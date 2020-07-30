// exptab.v: lookup exponential values for Yamaha-style FM
// 2016-05-05 E. Brombaugh

module exptab(clk, addr, expo);
	parameter asz = 8;				// Bits in address word
	parameter osz = 10;				// Bits in output word
	parameter msz = 2**asz;			// words in memory
	
	input clk;						// Main system clock
	input [asz-1:0] addr;			// table address
	output [osz-1:0] expo;			// output
	
	// sine LUT
	reg signed [osz-1:0] LUT[0:msz-1];
	initial
		$readmemh("../src/exptab.hex", LUT, 0);
		
	// Sync output register
	reg signed [osz-1:0] expo;		// output
	always @(posedge clk)
		expo <= LUT[addr];
endmodule

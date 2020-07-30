// sintab.v: lookup logarithmic sine values for Yamaha-style FM
// 2016-05-05 E. Brombaugh

module sintab(clk, addr, sine);
	parameter asz = 8;				// Bits in address word
	parameter osz = 12;				// Bits in output word
	parameter msz = 2**asz;			// words in memory
	
	input clk;						// Main system clock
	input [asz-1:0] addr;			// table address
	output [osz-1:0] sine;			// output
	
	// sine LUT
	reg signed [osz-1:0] LUT[0:msz-1];
	initial
		$readmemh("../src/sintab.hex", LUT, 0);
		
	// Sync output register
	reg signed [osz-1:0] sine;		// output
	always @(posedge clk)
		sine <= LUT[addr];
endmodule

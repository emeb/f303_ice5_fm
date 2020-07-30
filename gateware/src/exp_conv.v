// exp_conv.v: attenuate in log domain and convert to linear
// 2016-05-05 E. Brombaugh

module exp_conv(clk, wave, atten, out);
	parameter wsz = 16;				// Bits in wave word
	parameter asz = 9;				// Bits in atten word
	parameter osz = 12;			    // Bits in output word
	
	input clk;						// Main system clock
	input [wsz-1:0] wave;			// waveform input
	input [asz-1:0] atten;			// attenuation input
	output signed [osz-1:0] out;	// output
	
	// detect silence condition
	wire silent = atten == 9'h1ff;
	
	// add wave and atten in log domain to multiply
	reg dsilent;
	reg [wsz-1:0] sum;
	always @(posedge clk)
	begin
		dsilent <= silent;
		sum <= wave + (atten << 3);
	end
	
	// get sign bit
	wire sign = sum[wsz-1];
	
	// get the shift value
	wire [6:0] shift = sum[wsz-2:8];
	
	// get lut address value
	wire [7:0] addr = sum[7:0]^8'hff;
	
	// look up linear value
	wire [9:0] lutval;
	exptab
		i_LUT(.clk(clk), .addr(addr), .expo(lutval));
	
	// pipeline the sign and shift to match delay through LUT
	reg ddsilent, dsign;
	reg [6:0] dshift;
	always @(posedge clk)
	begin
		ddsilent <= dsilent;
		dsign <= sign;
		dshift <= shift;
	end
	
	// form linear value
	wire [11:0] linval = {2'b01,lutval};
	
	// apply shift
	wire [11:0] shiftval = linval >> dshift;
	
	// apply sign
	wire [11:0] signval = dsign ? shiftval ^ 12'hfff : shiftval;
	
	// Sync output register
	reg signed [osz-1:0] out;
	always @(posedge clk)
		out <= ddsilent ? 12'h000 : signval;
endmodule

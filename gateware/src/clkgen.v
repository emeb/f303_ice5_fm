//
// clkgen: Clock generation for I2S serializer
//
// mclk = clk/4. 
// @ 48MHz => 12MHz master rate
// rate = mclk/256. 
// @ 48MHz => 46.875 kHz sample rate
//
module clkgen(clk, reset, mclk, mclk_ena, rate);
	input clk;		// 48MHz system clock
	input reset;	// POR
	output mclk;	// 256x master clock output (50% duty cycle)
	output mclk_ena;// 256x master clock enable output (25% duty cycle)
	output rate;	// Sample rate clock output
	
	// master clock divider (4x)
	reg [1:0] mclk_cnt;
	reg mclk_ena;
	always @(posedge clk)
		if(reset)
		begin
			mclk_cnt <= 2'b11;
			mclk_ena <= 1'b1;
		end
		else
		begin
			mclk_cnt <= mclk_cnt - 1;
			if(mclk_cnt == 2'b00)
				mclk_ena <= 1'b1;
			else
				mclk_ena <= 1'b0;
		end
		
	assign mclk = mclk_cnt[1];
	
	// rate counter
	reg rate;
	reg [7:0] rate_cnt;
	always @(posedge clk)
		if(reset | rate)
			rate_cnt <= 8'd255;
		else if(mclk_ena)
			rate_cnt <= rate_cnt - 1;
	
	// detect end condition for one cycle pulse in sync with mclk_ena
	always @(posedge clk)
		rate <= ((rate_cnt == 8'd0) && (mclk_cnt == 2'b00));
endmodule

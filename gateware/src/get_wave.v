// get_wave.v: look up wavetable data
// 2016-05-06 E. Brombaugh

module get_wave(clk, wv, phs, out);
	parameter wsz = 3;				// Bits in wave word
	parameter psz = 10;				// Bits in phase word
	parameter osz = 16;			    // Bits in output word
	
	input clk;						// Main system clock
	input [wsz-1:0] wv;				// waveform input
	input [psz-1:0] phs;			// attenuation input
	output signed [osz-1:0] out;	// output
	
	// control signals based on wave type
	reg sign, inv;
	reg [7:0] idx;
	reg [2:0] src;
	always @(posedge clk)
		case(wv)
			3'd0: // Full Sine
			begin
				sign <= phs[psz-1];
				inv <= phs[psz-2];
				idx <= phs[psz-3:psz-10];
				src <= 3'b000;						// lut
			end
			
			3'd1: // Positive Half Sine + zero
			begin
				sign <= 0;
				inv <= phs[psz-2];
				idx <= phs[psz-3:psz-10];
				src <= {2'b00,phs[psz-1]};			// lut or zero
			end
			
			3'd2: // Positive Half Sine x 2
			begin
				sign <= 0;
				inv <= phs[psz-2];
				idx <= phs[psz-3:psz-10];
				src <= 3'b000;						// lut
			end
			
			3'd3: // Positive Quarter Sine + zero x 2
			begin
				sign <= 0;
				inv <= phs[psz-2];					// don't care
				idx <= phs[psz-3:psz-10];
				src <= {2'b00,phs[psz-2]};			// lut or zero
			end
			
			3'd4: // Full Sine2F + zero
			begin
				sign <= phs[psz-2];
				inv <= phs[psz-3]; 					// 2x freq
				idx <= {phs[psz-4:psz-10],phs[psz-3]}; // 2x freq
				src <= {2'b00,phs[psz-1]};			// lut or zero
			end
			
			3'd5: // Positive Half Sine2F x 2 + zero
			begin
				sign <= 0;
				inv <= phs[psz-3]; 					// 2x freq
				idx <= {phs[psz-4:psz-10],phs[psz-3]}; // 2x freq
				src <= {2'b00,phs[psz-1]};			// lut or zero
			end
			
			3'd6: // Square
			begin
				sign <= phs[psz-1];
				inv <= phs[psz-2];					// don't care
				idx <= phs[psz-3:psz-10];			// don't care
				src <= 3'b010;						// max
			end
				
			3'd7: // Expo Saw
			begin
				sign <= phs[psz-1];
				inv <= phs[psz-1];
				idx <= phs[psz-3:psz-10];
				src <= {2'b10,phs[psz-1]^phs[psz-2]}; // direct or direct + offset
			end			
		endcase
	
	// invert index into LUT
	wire [7:0] addr = inv ? idx ^ 8'hff : idx;
	
	// lookup sine values
	wire [11:0] lutval;
	sintab
		i_LUT(.clk(clk), .addr(addr), .sine(lutval));
	
	// pipeline the controls to match delay through LUT
	reg dsign;
	reg [7:0] daddr;
	reg [2:0] dsrc;
	always @(posedge clk)
	begin
		dsign <= sign;
		daddr <= addr;
		dsrc <= src;
	end
	
	// select the output source and register
	reg signed [osz-1:0] out;
	always @(posedge clk)
	begin
		// select type
		case(dsrc)
			3'd0: out <= {dsign,3'b0,lutval};		// Sine LUT w/ inversion
			3'd1: out <= 16'h0C00;			// Zero value
			3'd2: out <= {dsign,15'b0};		// max w/ inversion
			3'd3: out <= 16'bx;				// Unused - don't care
			3'd4: out <= {dsign,4'h0,daddr,3'b0};	// index shift
			3'd5: out <= {dsign,4'h1,daddr,3'b0};	// index shift + offset
			3'd6: out <= 16'bx;				// Unused - don't care
			3'd7: out <= 16'bx;				// Unused - don't care
		endcase
	end
endmodule

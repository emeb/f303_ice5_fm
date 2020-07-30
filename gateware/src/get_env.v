// get_env.v: Yamaha-style envelope generation
// 2016-05-07 E. Brombaugh

module get_env(clk, active, trig, ar, dr, sl, rr, adj,
		i_st, i_ctr, i_val, o_st, o_ctr, o_val, atten);
	parameter rsz = 6;				// Bits in rate word
	parameter lsz = 5;				// Bits in level word
	parameter asz = 9;				// Bits in atten word
	parameter csz = 15;				// Bits in counter word
	
	input clk;						// Main system clock
	input active;					// Envelope start/stop (keydown)
	input trig;						// Envelope trigger (keydown)
	input [rsz-1:0] ar, dr, rr;		// attack, decay, release rates
	input [lsz-1:0] sl;				// sustain level
	input [asz-1:0] adj;			// attenuation adjust
	input [1:0] i_st;				// input state
	input [csz-1:0] i_ctr;			// input timing counter
	input [asz-1:0] i_val;			// input attenuation value
	output [1:0] o_st;				// output state
	output [csz-1:0] o_ctr;			// output counter
	output [asz-1:0] o_val;			// output attenuation value
	output [asz-1:0] atten;			// attenuation value to expo calcs
	
	// state machine update & rate select
	reg [1:0] pppppo_st;
	reg [rsz-1:0] rate;
	always @(*)
		case(i_st)
			2'd0:	// attack state
			begin
				if(i_val == 0)
					pppppo_st = 2'd1;	// min atten so move to decay state
				else
					pppppo_st = 2'd0;	// stay in attack state
				rate = ar;			// use attack rate
			end
			
			2'd1:	// decay state
			begin
				if(i_val[asz-1:asz-5] >= sl)
					pppppo_st = 2'd2;	// atten ~= sustain so move to sustain state
				else
					pppppo_st = 2'd1;	// stay in decay state
				rate = dr;			// use decay rate
			end
			
			2'd2:	// sustain state
			begin
				if(active == 1'b0)
					pppppo_st = 2'd3;	// key up so move to decay state
				else
					pppppo_st = 2'd2;	// stay in sustain state
				rate = {rsz{1'b0}};	// no rate
			end
			
			2'd3:	// release state
			begin
				if(trig == 1'b1)
					pppppo_st = 2'd0;		// trigger so move to attack state
				else
					pppppo_st = 2'd3;		// stay in release state
				rate = rr;			// use release rate
			end
		endcase
	
	// expand rate to 18 bits
	reg [csz+2:0] ctr_inc;
	reg [1:0] ppppo_st, di_st;	// output state, input state
	reg [asz-1:0] di_val, dadj;	// input attenuation value, adjust
	reg [csz-1:0] di_ctr;
	always @(posedge clk)
	begin
		ppppo_st <= pppppo_st;
		di_st <= i_st;
		di_ctr <= i_ctr;
		ctr_inc <= {1'b1,rate[1:0]}<<rate[rsz-1:2];
		di_val <= i_val;
		dadj <= adj;
	end
	
	// pipeline register - state, counter sum, i_val, 
	reg [1:0] pppo_st, ddi_st;	// output state, input state
	reg [csz+2:0] ctr_sum;
	reg [asz-1:0] ddi_val, ddadj;	// input attenuation value, adjust
	always @(posedge clk)
	begin
		pppo_st <= ppppo_st;
		ddi_st <= di_st;
		ctr_sum <= {3'b000,di_ctr} + ctr_inc;
		ddi_val <=di_val;
		ddadj <= dadj;
	end
	
	// parse counter into next count value and overflow
	wire [2:0] ctr_ovfl = ctr_sum[csz+2:csz];
	
	// compute attack scaled value
	reg [1:0] ppo_st, dddi_st;	// output state, input state
	reg [asz-1:0] mul_val;		// attack scaled value
	reg [asz-1:0] dddi_val, dddadj;	// input attenuation value, adjust
	reg [csz-1:0] ppo_ctr;
	reg [2:0] dctr_ovfl;
	always @(posedge clk)
	begin
		// delay output state
		ppo_st <= pppo_st;

		// delay counter output
		ppo_ctr <= ctr_sum[csz-1:0];
		dctr_ovfl <= ctr_ovfl;
		
		// delay input state
		dddi_st <= ddi_st;
		
		dddi_val <=ddi_val;
		dddadj <= ddadj;
		
		// multiplier value
		mul_val <= (ddi_val * ctr_ovfl)>>3;
	end
	
	// compute new attenuation value
	reg [1:0] po_st;
	reg [csz-1:0] po_ctr;
	reg [asz:0] val_sum;
	reg [asz-1:0] ddddadj;	// adjust
	always @(posedge clk)
	begin
		// delay output state
		po_st <= ppo_st;

		// delay counter output
		po_ctr <= ppo_ctr;

		// update value
		if(dddi_st == 2'd0)			// attack is exponential
			if(dctr_ovfl == 0)
				val_sum <= dddi_val;	// no change
			else
				val_sum <= dddi_val - (mul_val + 1);
		else if(dddi_st[0] == 1'b1)	// decay and release are normal
			val_sum <= dddi_val + dctr_ovfl;
		else						// no change
			val_sum <= dddi_val;
		
		// delay adjust
		ddddadj <= dddadj;
	end
		
	// sum for final adjust
	wire [asz:0] atten_sum = val_sum + ddddadj;
	
	// clamp to limits & assign output
	reg [1:0] o_st;
	reg [csz-1:0] o_ctr;
	reg [asz-1:0] o_val, atten;
	always @(posedge clk)
	begin
		o_st <= po_st;
		o_ctr <= po_ctr;
		o_val <= (val_sum <= 10'd511) ? val_sum[asz-1:0] : 10'd511;
		atten <= (atten_sum <= 10'd511) ? atten_sum[asz-1:0] : 10'd511;
	end
endmodule

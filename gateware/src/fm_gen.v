// fm_gen.v: Yamaha-style fm generation
// 2016-06-01 E. Brombaugh

module fm_gen(clk, reset, ena_smpl,
		gate, frq, ar, dr, 
		sl, rr, adj, wv, ri, li,
		mod_en, acc_en, acc_cl, fb_en,
		pwaddr, pwe,
		audio_l, audio_r,
		readbus);
	parameter fsz = 19;				// Bits in freq word
	parameter rsz = 6;				// Bits in rate word
	parameter lsz = 5;				// Bits in level word
	parameter asz = 9;				// Bits in atten word
	parameter csz = 15;				// Bits in counter word
	parameter osz = 7;				// Bits in operator address
	parameter ops = 128;			// number of operators
	
	input clk;						// Main system clock
	input reset;					// POR
	input ena_smpl;					// sample clock enable
	input [15:0] gate;				// Envelope start/stop (keydown)
	input [fsz-1:0] frq;			// param in - Frequency word
	input [rsz-1:0] ar, dr, rr;		// param in - attack, decay, release rates
	input [lsz-1:0] sl;				// param in - sustain level
	input [asz-1:0] adj;			// param in - attenuation adjust
	input [2:0] wv;					// param in - waveform select
	input ri;						// param in - right out include
	input li;						// param in - left out include
	input mod_en;					// param in - enable modulation input 
	input acc_en;					// param in - enable accumlation
	input acc_cl; 					// param in - clear accumulator
	input fb_en;					// param in - feedback enable (only one per algo)
	input [6:0] pwaddr;				// op address for parameter write
	input pwe;						// parameter write strobe
	output signed [15:0] audio_l;	// final audio out
	output signed [15:0] audio_r;	// final audio out
	output [63:0] readbus;			// parameter diagnostic
	
	// trigger edge detector
	reg [15:0] dgate, ddgate;
	always @(posedge clk)
	begin
		if(reset)
		begin
			dgate <= 16'b0;
			ddgate <= 16'b0;
		end
		else
		begin
			if(ena_smpl)
			begin
				dgate <= gate;
				ddgate <= dgate;
			end
		end
	end
	wire [15:0] trig = dgate & ~ddgate;
	
	// syncable 1/8 enable generator and op counter
	reg [2:0] enacnt;
	reg ena_8;
	reg [9:0] ena_8d;
	reg [osz-1:0] opcnt, opcnt_d;
	reg ramclr;
	always @(posedge clk)
	begin
		if(reset)
		begin
			enacnt <= 3'b000;
			ena_8 <= 1'b1;
			ena_8d <= 10'h000;
			opcnt <= 7'h00;
			opcnt_d <= 7'h00;
			ramclr <= 1'b1;
		end
		else
		begin
			if(ramclr)
			begin
				opcnt <= opcnt + 7'd1;
				if(opcnt == 7'd127)
					ramclr <= 1'b0;
			end
			else
			begin
				if(ena_smpl)
				begin
					enacnt <= 3'b001;
					ena_8 <= 1'b0;
					opcnt <= 7'h00;
				end
				else
				begin
					enacnt <= enacnt + 3'd1;
				
					if(enacnt == 3'b111)
						ena_8 <= 1'b1;
					else
						ena_8 <= 1'b0;
								
					if(ena_8)
						opcnt <= opcnt + 7'd1;
				end
				
				ena_8d <= {ena_8d[8:0],ena_8};
				
				if(ena_8d[7])
					opcnt_d <= opcnt;
			end
		end
	end
	
	// Parameter storage memory - 64 bits x 127 ops -> 4 block RAMs
	reg [63:0] pmem [ops-1:0];
	wire [63:0] pwdata = 
	{
		4'h0,	// [63:60] 4-bit unused
		fb_en,	//    [59] 1-bit feedback enable (only one per algo)
		acc_cl, //    [58] 1-bit clear accumulator
		acc_en,	//    [57] 1-bit enable accumlation
		mod_en,	//    [56] 1-bit enable modulation input 
		ri,		//    [55] 1-bit right out include
		li,		//    [54] 1-bit left out include
		rr,		// [53:48] 6-bit release rate
		sl,		// [47:43] 5-bit sustain level (attenuation)
		dr,		// [42:37] 6-bit decay rate
		ar,		// [36:31] 6-bit attack rate
		adj,	// [30:22] 9-bit attenuation adjust 
		wv,		// [21:19] 3-bit waveform
		frq		//  [18:0] 19-bit base frequency
	};
	always @(posedge clk) // Write memory.
	begin
		if(ramclr)
			pmem[opcnt] <= 64'h0; // Using write address bus.
		else if (pwe)
			pmem[pwaddr] <= pwdata; // Using write address bus.
	end
	
	reg [63:0] pout;
	always @(posedge clk) // Read memory.
		pout <= pmem[opcnt]; // Using opcnt.
	
	// parameter diagnostic
	reg [63:0] readbus;
	always @(posedge clk)
		if((opcnt == pwaddr) & ena_8d[1])
			readbus <= pout;
		
	// break out parameters
	wire [fsz-1:0] p_frq;
	wire [rsz-1:0] p_ar, p_dr, p_rr;
	wire [lsz-1:0] p_sl;
	wire [asz-1:0] p_adj;
	wire [2:0] p_wv;
	wire p_ri, p_li, p_mod_en,p_acc_en,p_acc_cl,p_fb_en;
	wire [4:0] p_dummy;
	assign
	{
		p_dummy,
		p_fb_en,
		p_acc_cl,
		p_acc_en,
		p_mod_en,
		p_ri,
		p_li,
		p_rr,
		p_sl,
		p_dr,
		p_ar,
		p_adj,
		p_wv,
		p_frq
	} = pout;
	
	// delay some of the params to 2nd cycle
	reg	p_ri_d, p_li_d, p_acc_cl_d, p_acc_en_d;
	reg p_fb_en_d;
	always @(posedge clk)
	begin
		if(reset)
		begin
			p_ri_d <= 1'b0;
			p_li_d <= 1'b0;
			p_acc_cl_d <= 1'b0;
			p_acc_en_d <= 1'b0;
			p_fb_en_d <= 1'b0;
		end
		else
		begin
			if(ena_8d[7])
			begin
				p_ri_d <= p_ri;
				p_li_d <= p_li;
				p_acc_cl_d <= p_acc_cl;
				p_acc_en_d <= p_acc_en;
				p_fb_en_d <= p_fb_en;
			end
		end
	end

	// state storage memory - 48 bits x 127 ops -> 3 block RAMs
	reg [47:0] smem [ops-1:0];
	reg [18:0] o_phs;
	wire [1:0] o_st;
	wire [14:0] o_ctr;
	wire [8:0] o_val;
	wire [47:0] swdata =
	{
		3'h0,	// [47:45] 3-bit unused
		o_val,	// [44:36] 9-bit envelope attenuation
		o_st,	// [35:34] 2-bit envelope state
		o_ctr,	// [33:19] 15-bit envelope delay counter
		o_phs	//  [18:0] 19-bit operator waveform phase
	};
	wire [47:0] st_rst =
	{
		3'h0,	// [47:45] 3-bit unused
		9'd511,	// [44:36] 9-bit envelope attenuation = max atten
		2'd3,	// [35:34] 2-bit envelope state = release
		15'd0,	// [33:19] 15-bit envelope delay counter = 0
		19'd0	//  [18:0] 19-bit operator waveform phase = 0
	};
	wire swe = ena_8d[6];				// write updated state at cycle 7
	always @(posedge clk) 				// Write memory.
	begin
		if (ramclr)
			smem[opcnt] <= st_rst; 		// Using write address bus.
		else if (swe)
			smem[opcnt] <= swdata; 		// Using write address bus.
	end
	
	reg [47:0] sout;
	always @(posedge clk) 				// Read memory.
		sout <= smem[opcnt]; 			// Using opcnt.
	
	// break out the state
	wire [18:0] s_phs;
	wire [1:0] s_st;
	wire [14:0] s_ctr;
	wire [8:0] s_val;
	wire [2:0] s_dummy;
	assign
	{
		s_dummy,
		s_val,
		s_st,
		s_ctr,
		s_phs
	} = sout;

	wire [11:0] op_out;					// operator output for summing
	reg [15:0] fmem [31:0];				// fb memory - 16 bits x 2 locs x 16 voices -> 1 block RAMs
	reg [15:0] fout;					// fb memory read data
	wire fwe = |ena_8d[4:3] & p_fb_en_d;	// fb memory write enable
	wire faccsel = ena_8d[2];			// fb accum input select
	wire faccena = |ena_8d[3:2];		// fb accum write enable
	wire faddr = ena_8d[4] | ena_8d[1];	// fb memory addr lsb
	wire facc = faccsel;				// fb accum / dump ctrl
	wire fwsel = ena_8d[4];				// fb write bus mux sel
	wire fasel = |ena_8d[4:2];          // fb r/w address select
	wire [4:0] frwaddr = fasel ? {opcnt_d[6:3],faddr} : {opcnt[6:3],faddr};		// fb r/w address
	wire signed [16:0] fb_acc_in = faccsel ? {{4{op_out[11]}},op_out} : fout;
	reg signed [16:0] fb_acc;			// fb accum
	wire signed [15:0] fwdata = fwsel ? fb_acc[16:1] : {{4{op_out[11]}},op_out}; // fb memory write data
	
	// Write memory
	always @(posedge clk)
	begin
		if (ramclr)
			fmem[opcnt[6:2]] <= 16'h0000;
		else if (fwe)
			fmem[frwaddr] <= fwdata;
	end
	
	// Read memory
	always @(posedge clk)
	begin
		fout <= fmem[frwaddr];
	end
	
	// accumulator
	always @(posedge clk)
	begin
		if(faccena)
		begin
			if(facc)
				fb_acc <= fb_acc_in;	// load
			else
				fb_acc <= fb_acc + fb_acc_in;	// accumulate
		end
	end

	// mux the gate & trigger
	reg mtrig, mgate;
	always @(posedge clk)
	begin
		if(reset)
		begin
			mtrig <= 1'b0;
			mgate <= 1'b0;
		end
		else if(ena_8d[0])
		begin
			mtrig <= trig[opcnt[6:3]];
			mgate <= dgate[opcnt[6:3]];
		end
	end
	
	// NCO phase calc
	reg [18:0] phs;
	always @(posedge clk)
	begin
		if(reset)
			phs <= 19'd0;
		else
		begin
			if(ena_8d[1])
			begin
				if(mtrig)
					phs <= 19'd0;
				else
					phs <= s_phs + p_frq;
			end
		end
	end
	
	// Modulation accumulator
	reg [9:0] mod_acc; 	// only bottom 10 bits used - others wrap
	always @(posedge clk)
	begin
		if(reset)
			mod_acc <= 10'd0;
		else
		begin
			if(ena_8d[9])
			begin
				if(p_acc_cl_d | (opcnt_d[2:0] == 3'd0))
				begin
					if(p_acc_en_d)
						mod_acc <= op_out[9:0];	// start new accum
					else
						mod_acc <= 10'd0;	// just clear
				end
				else
				begin
					if(p_acc_en_d)
						mod_acc <= mod_acc + op_out[9:0];	// accumulate
				end
			end
		end
	end
				
	// add modulation source to phase and truncate to 10 bits for wave LUT
	reg [9:0] phsmod;
	always @(posedge clk)
	begin
		if(reset)
			phsmod <= 19'd0;
		else
		begin
			if(ena_8d[2])
			begin
				if(p_mod_en)
					phsmod <= phs[18:9] + (p_fb_en ? fout[9:0] : mod_acc);
				else
					phsmod <= phs[18:9];
			end
		end
	end
	
	// delay phase to align with env state out
	always @(posedge clk)
	begin
		if(reset)
			o_phs <= 19'd0;
		else
		begin
			if(ena_8d[3])
				o_phs <= phs;
		end
	end
	
	// instantiate the waveform generator - 3 clocks latency
	wire [15:0] wvfrm;
	get_wave
		u_wave(.clk(clk), .wv(p_wv), .phs(phsmod), .out(wvfrm));
		
	// instantiate the envelope generator - 5 clocks latency
	wire [8:0] atten;
	get_env
		u_env(.clk(clk),
			.active(mgate), .trig(mtrig),
			.ar(p_ar), .dr(p_dr), .sl(p_sl), .rr(p_rr), .adj(p_adj),
			.i_st(s_st), .i_ctr(s_ctr), .i_val(s_val),
			.o_st(o_st), .o_ctr(o_ctr), .o_val(o_val), .atten(atten));

	// instantiate the expo converter - 3 clocks latency
	exp_conv
		u_expo(.clk(clk), .wave(wvfrm), .atten(atten), .out(op_out));
		
	// accumulate osc output
	wire signed [15:0] op_out_sx = {{4{op_out[11]}},op_out};
	reg signed [15:0] acc_l, acc_r;		// output accumulators
	reg signed [15:0] audio_l, audio_r;	// final audio out
	always @(posedge clk)
		if(reset)
		begin
			acc_l <= 16'h000;
			acc_r <= 16'h000;
			audio_l <= 16'h000;
			audio_r <= 16'h000;
		end
		else
		begin
			if(ena_8d[9])
			begin
				if(opcnt_d == 7'h00)
				begin
					// dump
					audio_l <= acc_l;
					audio_r <= acc_r;
					acc_l <= p_li_d ? op_out_sx : 16'h000;
					acc_r <= p_ri_d ? op_out_sx : 16'h000;
				end
				else
				begin
					// accumulate
					acc_l <= acc_l + (p_li_d ? op_out_sx : 16'h000);
					acc_r <= acc_r + (p_ri_d ? op_out_sx : 16'h000);
				end
			end
		end
endmodule

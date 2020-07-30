// lattice ice5lp4k fm osc + spi_slave + R G B blinky
// 05-07-16 E. Brombaugh

module f303_ice5_fm(
	// I2S output
	output mclk,
	output sdout,
	output sclk,
	output lrck,

	// SPI slave port
	input SPI_CSL,
	input SPI_MOSI,
	output SPI_MISO,
	input SPI_SCLK,
	
	// RGB output
	output wire o_red,
	output wire o_green,
	output wire o_blue
);

	// This should be unique so firmware knows who it's talking to
	parameter DESIGN_ID = 32'h13370005;

	//------------------------------
	// Instantiate HF Osc with div 1
	//------------------------------
	wire clk;
	SB_HFOSC #(.CLKHF_DIV("0b00")) OSCInst0 (
		.CLKHFEN(1'b1),
		.CLKHFPU(1'b1),
		.CLKHF(clk)
	) /* synthesis ROUTE_THROUGH_FABRIC= 0 */;
	
	//----------------------------------------------------------------------
	// reset generator - 4 clocks of high-true reset after coming out of cfg
	//----------------------------------------------------------------------
	reg [3:0] reset_pipe = 4'h0;
	reg reset = 1'b0;
	always @(posedge clk)
	begin
		reset <= ~(&reset_pipe);
		reset_pipe <= {reset_pipe[2:0],1'b1};
	end
	
	//------------------------------
	// Internal SPI slave port
	//------------------------------
	wire [31:0] wdat;
	reg [31:0] rdat;
	wire [6:0] addr;
	wire re, we;
	spi_slave
		uspi(.clk(clk), .reset(reset),
			.spiclk(SPI_SCLK), .spimosi(SPI_MOSI),
			.spimiso(SPI_MISO), .spicsl(SPI_CSL),
			.we(we), .re(re), .wdat(wdat), .addr(addr), .rdat(rdat));
	
	//------------------------------
	// Writeable registers
	//------------------------------
	reg [13:0] cnt_limit_reg;
	reg [18:0] freq;
	reg [15:0] gate;
	reg [2:0] wv;
	reg [5:0] ar, dr, rr;
	reg [4:0] sl;
	reg [8:0] adj;
	reg ri, li, mod_en, acc_en, acc_cl, fb_en;
	reg [6:0] pwaddr;
	always @(posedge clk)
	begin
		if(reset)
		begin
			cnt_limit_reg <= 14'd2499;	// 1/4 sec blink rate
			freq <= 19'd11185;			// 1kHz audio freq
			gate <= 16'd0;
			wv <= 3'd0;
			ar <= 6'd30;
			dr <= 6'd20;
			sl <= 6'd0;
			rr <= 6'd40;
			adj <= 9'd20;
			ri <= 1'b0;
			li <= 1'b0;
			mod_en <= 1'b0;
			acc_en <= 1'b0;
			acc_cl <= 1'b0;
			fb_en <= 1'b0;
			pwaddr <= 7'h00;
		end
		else if(we)
		begin
			case(addr)
				7'h01: cnt_limit_reg <= wdat;
				7'h02: freq <= wdat;
				7'h03: gate <= wdat;
				7'h04: wv <= wdat;
				7'h05: ar <= wdat;
				7'h06: dr <= wdat;
				7'h07: sl <= wdat;
				7'h08: rr <= wdat;
				7'h09: adj <= wdat;
				7'h0A: {ri,li,mod_en,acc_en,acc_cl,fb_en} <= wdat;
				7'h0B: pwaddr <= wdat;
			endcase
		end
	end
	
	//------------------------------
	// FM Parameter Write Enable - stretch to two clocks
	//------------------------------
	reg [1:0] pwe_pipe = 2'b00;
	reg pwe = 1'b0;
	always @(posedge clk)
	begin
		pwe_pipe <= {pwe_pipe[0],((addr == 7'h0C) & wdat[0] & we)};
		pwe <= |pwe_pipe;
	end
	
	//------------------------------
	// FM Reset - stretch to two clocks
	//------------------------------
	reg [1:0] fm_rst_pipe = 2'b00;
	reg fm_rst = 1'b0;
	always @(posedge clk)
	begin
		fm_rst_pipe <= {fm_rst_pipe[0],(reset | ((addr == 7'h0C) & wdat[1] & we))};
		fm_rst <= |fm_rst_pipe;
	end
			
	//------------------------------
	// readback
	//------------------------------
	wire [63:0] readbus;
	always @(*)
	begin
		case(addr)
			7'h00: rdat = DESIGN_ID;
			7'h01: rdat = cnt_limit_reg;
			7'h02: rdat = freq;
			7'h03: rdat = gate;
			7'h04: rdat = wv;
			7'h05: rdat = ar;
			7'h06: rdat = dr;
			7'h07: rdat = sl;
			7'h08: rdat = rr;
			7'h09: rdat = adj;
			7'h0A: rdat = {ri,li,mod_en,acc_en,acc_cl,fb_en};
			7'h0B: rdat = pwaddr;
			7'h0E: rdat = readbus[31:0];
			7'h0F: rdat = readbus[63:32];
			default: rdat = 32'd0;
		endcase
	end
	
	// Audio Sample rate enable
	wire audio_ena;
	
	// FM Generator
	wire signed [15:0] l_data, r_data;
	fm_gen
		ufm(.clk(clk), .reset(fm_rst), .ena_smpl(audio_ena),
			.gate(gate), .frq(freq), .ar(ar), .dr(dr),
			.sl(sl), .rr(rr), .adj(adj), .wv(wv), .ri(ri), .li(li),
			.mod_en(mod_en), .acc_en(acc_en), .acc_cl(acc_cl), .fb_en(fb_en),
			.pwaddr(pwaddr), .pwe(pwe),
			.audio_l(l_data), .audio_r(r_data),
			.readbus(readbus));
			
	// I2S serializer
	i2s_out
		ui2s(.clk(clk), .reset(reset),
			.l_data(l_data), .r_data(r_data),
			.mclk(mclk), .sdout(sdout), .sclk(sclk), .lrclk(lrck),
			.load(audio_ena));
	
	//------------------------------
	// Instantiate LF Osc
	//------------------------------
	wire CLKLF;
	SB_LFOSC OSCInst1 (
		.CLKLFEN(1'b1),
		.CLKLFPU(1'b1),
		.CLKLF(CLKLF)
	) /* synthesis ROUTE_THROUGH_FABRIC= 0 */;
	
	//------------------------------
	// Divide the clock
	//------------------------------
	reg [13:0] clkdiv = 14'h0000;
	reg onepps;
	always @(posedge CLKLF)
	begin		
		if(clkdiv == 14'd0)
		begin
			onepps <= 1'b1;
			clkdiv <= cnt_limit_reg;
		end
		else
		begin
			onepps <= 1'b0;
			clkdiv <= clkdiv - 14'd1;
		end
	end
	
	//------------------------------
	// LED signals
	//------------------------------
	reg [2:0] state = 3'h0;
	always @(posedge CLKLF)
	begin
		if(onepps)
			state <= state + 3'd1;
	end
	
	//------------------------------
	// Instantiate RGB DRV 
	//------------------------------
	wire red_pwm_i = state[0];
	wire grn_pwm_i = state[1];
	wire blu_pwm_i = state[2];
	SB_RGB_DRV RGB_DRIVER (
	   .RGBLEDEN  (1'b1), // Enable current for all 3 RGB LED pins
	   .RGB0PWM   (red_pwm_i), // Input to drive RGB0 - from LEDD HardIP
	   .RGB1PWM   (grn_pwm_i), // Input to drive RGB1 - from LEDD HardIP
	   .RGB2PWM   (blu_pwm_i), // Input to drive RGB2 - from LEDD HardIP
	   .RGBPU     (led_power_up_i), //Connects to LED_DRV_CUR primitive
	   .RGB0      (o_red), 
	   .RGB1      (o_green),
	   .RGB2      (o_blue)
	);
	defparam RGB_DRIVER.RGB0_CURRENT = "0b000111";
	defparam RGB_DRIVER.RGB1_CURRENT = "0b000111";
	defparam RGB_DRIVER.RGB2_CURRENT = "0b000111";

	//------------------------------
	// Instantiate LED CUR DRV 
	//------------------------------
	SB_LED_DRV_CUR LED_CUR_inst (
		.EN    (1'b1), //Enable to supply reference current to the LED drivers
		.LEDPU (led_power_up_i) //Connects to SB_RGB_DRV primitive
	);

endmodule

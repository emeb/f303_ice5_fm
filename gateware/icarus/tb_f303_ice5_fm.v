// tb_f303_ice5_fm.v: top-level testbench for FM generator in Lattice iCE40-Ultra
// 2016-06-02 E. Brombaugh

module tb_f303_ice5_fm;
	// I2S output
	wire mclk;
	wire sdout;
	wire sclk;
	wire lrck;

	// SPI slave port
	reg SPI_CSL;
	reg SPI_MOSI;
	wire SPI_MISO;
	reg SPI_SCLK;
	
	// RGB output
	wire o_red;
	wire o_green;
	wire o_blue;
	
	// spi shift
	reg [39:0] sr;
	reg [31:0] read_data;
	
	// spi transaction task
	task spi_rxtx
		(
			input rw,
			input [6:0] addr,
			input [31:0] wdata
		);
		begin: spi_task
			
			sr = {rw,addr,wdata};
			SPI_CSL = 1'b0;
			SPI_SCLK = 1'b0;
			SPI_MOSI = sr[39];
			
			repeat(40)
			begin
				#100
				SPI_SCLK = 1'b1;
				#100
				SPI_SCLK = 1'b0;
				sr = {sr[38:0],SPI_MISO};
				SPI_MOSI = sr[39];
			end
			
			#100
			SPI_CSL = 1'b1;
			#100
			read_data = sr[31:0];
		end
	endtask
		
	f303_ice5_fm
		uut(
			// I2S output
			.mclk(mclk),
			.sdout(sdout),
			.sclk(sclk),
			.lrck(lrck),

			// SPI slave port
			.SPI_CSL(SPI_CSL),
			.SPI_MOSI(SPI_MOSI),
			.SPI_MISO(SPI_MISO),
			.SPI_SCLK(SPI_SCLK),
			
			// RGB output
			.o_red(o_red),
			.o_green(o_green),
			.o_blue(o_blue)
		);

	// test setup
	initial
    begin
`ifdef icarus
  		$dumpfile("tb_f303_ice5_fm.vcd");
		$dumpvars;
`endif
        
		// initial SPI setting
		SPI_CSL = 1'b1;
		SPI_MOSI = 1'b0;
		SPI_SCLK = 1'b0;
	
		// wait for chip to init
		#4000
		
		// read ID
		spi_rxtx(1'b1, 7'd00, 32'd0);
		
		// write params - assume the defaults are good
		spi_rxtx(1'b0, 7'd10, 32'b110000); // li, ri ena
		spi_rxtx(1'b0, 7'd11, 32'd0); // op 0
		spi_rxtx(1'b0, 7'd12, 32'd1); // write
	
		// wait for opcnt to cycle
		#22000
		
		// read diag bus
		spi_rxtx(1'b1, 7'h0E, 32'd0); // low
		spi_rxtx(1'b1, 7'h0F, 32'd0); // high
		
		// trigger on
		spi_rxtx(1'b0, 7'd3, 32'd1); // write
		
		// wait for opcnt to cycle
		//#22000
		
		// trigger off
		//spi_rxtx(1'b0, 7'd3, 32'd0); // write

`ifdef icarus
        // stop after 4ms
		#5000000 $finish;
`endif
	end
endmodule
	

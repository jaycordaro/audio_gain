/* Copyright 2023 Jay Cordaro

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation 
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS "AS IS" 
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY 
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
module audio_gain(input logic clk,
				  input logic reset_n,
				  input logic signed [15:0] x_in,    
				  output logic signed [15:0] y_out
				  input logic rd_en,
				  input logic wr_en,
				  input   [7:0] data_in,
				  output logic [7:0] data_out
				  );
		 
	logic signed [15:0] shift_gain_in;
	logic signed [18:0] shift_gain_out;
	logic signed [15:0] shifted_gain;
	
	logic signed [15:0] quarter_gain;
	logic signed [16:0] stage2_out;
	
	/* Config reg, connected to SPI
	   7      0 = reserved.  Write as 0 ignore on read
     6:4    000 = large gain/attenuation block disabled
	        001 = 6dB gain
			010 = 12dB gain
			011 = 18dB gain
			100 = reserved
			101 = -6dB 
			110 = -12dB 
			111 = -18dB
	   3      0 = 2, 4dB are positive gain
	          1 = 2, 4dB are negative gain
	   2      0 = 2nd 2dB gain block disabled
	          1 = 2nd 2dB gain block enabled
	   1      0 = 2dB gain disabled
		      1 = 2dB gain block enabled
	   0      0 = Gain disabled (bypass) default
	          1 = Gain block enabled
	 */ 
	logic [7:0] audio_gain_cfg_reg;
	
	always_ff @(posedge clk or negedge reset_n)
	if (~reset_n)
		begin
			audio_gain_cfg_reg <= 8'b0000_0000;
		end
	else if (wr_en == 1'b1)
		begin
			audio_gain_cfg_reg <= data_in;
		end

	always_ff @(posedge clk or negedge reset_n)
	if (~reset_n)
		begin
			data_out <= 8'b0000_0000;
		end
	else if (rd_en == 1'b1)
		begin
			data_out <= audio_gain_cfg_reg;
		end
	else if (~rd_en)
			data_out <= 8'b0000_0000;	 
	
	// 
	always_comb begin
		case (audio_gain_cfg_reg[6:4] 
			3'b111 : shift_gain_out = (shift_gain_in >>> 3);
			3'b110 : shift_gain_out = (shift_gain_in >>> 2);
			3'b101 : shift_gain_out = (shift_gain_in >>> 1);
			3'b100 : shift_gain_out = shift_gain_in;
			3'b011 : shift_gain_out = (shift_gain_in <<< 3);
			3'b010 : shift_gain_out = (shift_gain_in <<< 2);
			3'b001 : shift_gain_out = (shift_gain_in <<< 1);
			3'b000 : shift_gain_out = shift_gain_in;
		endcase
	end
	
	// saturate 
	
	always_comb begin
		if (shift_gain_out > 32767)
			shifted_gain = 32767;
		else if (shift_gain_out < -32768)
			shifted_gain = -32768;
		else
			shifted_gain = shift_gain_out;
	end
	
	// 2dB gain
	
	assign quarter_gain = $signed(shifted_gain >> 2);
	
	always_comb begin
		case (audio_gain_cfg_reg[3:1]
		    3'b111 : stage2_out = $signed(shifted_gain - quarter_gain - quarter_gain);
		    3'b110 : stage2_out = $signed(shifted_gain - quarter_gain);
		    3'b101 : stage2_out = $signed(shifted gain - quarter_gain);
			3'b100 : stage2_out = $signed(shifted_gain);
			3'b011 : stage2_out = $signed(shifted_gain + quarter_gain + quarter_gain);
			3'b010 : stage2_out = $signed(shifted_gain + quarter_gain);
			3'b001 : stage2_out = $signed(shifted_gain + quarter_gain);
			3'b000 : stage2_out = $signed(shifted_gain);
		endcase
	end
	
	always_ff @(posedge clk or negedge reset_n)
		if (~reset_n)
			y_out <= 0;
		else if (stage2_out > 32767 && audio_gain_cfg_reg[0] == 1'b1)
			y_out <= 32767;
		else if (stage2_out < -32768 && audio_gain_cfg_reg[0] == 1'b1)
			y_out <= -32768;
		else if (audio_gain_cfg_reg[0] == 1'b1)
			y_out <= stage2_out;
		else 
			y_out <= x_in;
	
endmodule : audio_gain

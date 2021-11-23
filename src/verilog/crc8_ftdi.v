//------------------------------------------------------------------------------------------------------//
//													         CRC8-CCITT FUNCTION 												  //
//------------------------------------------------------------------------------------------------------//
module crc8_ftdi 
(
	input		[7:0]		data_i,
	input		[7:0]		crc_i,
	
	output	[7:0]		crc_o
	
);

	wire [7:0] new_crc;

	wire [7:0] reg_d = data_i;
	wire [7:0] reg_c = crc_i;
	
	assign new_crc[0] = reg_d[7] ^ reg_d[6] ^ reg_d[0] ^ reg_c[0] ^ reg_c[6] ^ reg_c[7];
	assign new_crc[1] = reg_d[6] ^ reg_d[1] ^ reg_d[0] ^ reg_c[0] ^ reg_c[1] ^ reg_c[6];
	assign new_crc[2] = reg_d[6] ^ reg_d[2] ^ reg_d[1] ^ reg_d[0] ^ reg_c[0] ^ reg_c[1] ^ reg_c[2] ^ reg_c[6];
	assign new_crc[3] = reg_d[7] ^ reg_d[3] ^ reg_d[2] ^ reg_d[1] ^ reg_c[1] ^ reg_c[2] ^ reg_c[3] ^ reg_c[7];
	assign new_crc[4] = reg_d[4] ^ reg_d[3] ^ reg_d[2] ^ reg_c[2] ^ reg_c[3] ^ reg_c[4];
	assign new_crc[5] = reg_d[5] ^ reg_d[4] ^ reg_d[3] ^ reg_c[3] ^ reg_c[4] ^ reg_c[5];
	assign new_crc[6] = reg_d[6] ^ reg_d[5] ^ reg_d[4] ^ reg_c[4] ^ reg_c[5] ^ reg_c[6];
	assign new_crc[7] = reg_d[7] ^ reg_d[6] ^ reg_d[5] ^ reg_c[5] ^ reg_c[6] ^ reg_c[7];
	assign crc_o = new_crc;

endmodule




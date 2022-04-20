module usb_prot_decoder (
	input						clk
	,input					rst_n
	
	,input					op_i			//Operation active
	,input	[31:0]		op_dat_i		//Operation data
	,output					dat_en_o
	,output	[31:0]		dat_o
	,output	[15:0]		dat_len_o
	,output	[ 1:0]		dat_be_o
	,output					dat_crc_chk_o
	,output					dat_crc_true_o
	
	,output	[1:0]			test_o
);

reg					rcv_run_r1;
reg					rcv_run_r2;
reg					rcv_run_r3;
reg					rcv_run_r4;
reg					rcv_run_r5;
reg					data_run;
reg	[(4*8)-1:0]	dat_in_r1;
reg	[(4*8)-1:0]	dat_in_r2;
reg	[(4*8)-1:0]	dat_in_r3;
reg	[(4*8)-1:0]	header_r;
reg	[2:0]			header_cnt;
reg					header_fix;
reg					header_fix_r;
reg	[7:0]			data_crc_r;
reg	[(8*8)-1:0]	data_r;
reg	[16:0]		data_cnt;
reg	[ 2:0]		byte_en;
reg					crc_check_en;
reg					dat_crc_chk;

reg					flag_5E;
reg					flag_5E4D;
reg					flag_5E4D_r;
reg	[1:0]			flag_5E4D_ptr;
reg	[1:0]			flag_5E4D_ptr_r;

wire	[7:0]			crc_ho1;
wire	[7:0]			crc_ho2;
wire	[7:0]			crc_ho3;
wire	[7:0]			crc_do1;
wire	[7:0]			crc_do2;
wire	[7:0]			crc_do3;
wire	[7:0]			crc_do4;
wire					header_crc_true;
wire					trsmt_cmplt;
wire					last_byte;
wire	[15:0]		data_len;
wire	[7:0]			header_addr;
wire	[7:0]			header_numh;
wire	[7:0]			header_numl;
wire	[7:0]			header_crc;


//DATA RCV RUN REG 1
always @(posedge clk or negedge rst_n)
	if (!rst_n)				rcv_run_r1 <= 1'b0;
	else 						rcv_run_r1 <= op_i;
//DATA RCV RUN REG 2	
always @(posedge clk or negedge rst_n)
	if (!rst_n)				rcv_run_r2 <= 1'b0;
	else 						rcv_run_r2 <= rcv_run_r1;
//DATA RCV RUN REG 3
always @(posedge clk or negedge rst_n)
	if (!rst_n)				rcv_run_r3 <= 1'b0;
	else 						rcv_run_r3 <= rcv_run_r2;
//DATA RCV RUN REG 4										
always @(posedge clk or negedge rst_n)
	if (!rst_n)				rcv_run_r4 <= 1'b0;
	else 						rcv_run_r4 <= rcv_run_r3;
//DATA RCV RUN REG 5										
always @(posedge clk or negedge rst_n)
	if (!rst_n)				rcv_run_r5 <= 1'b0;
	else 						rcv_run_r5 <= rcv_run_r4;


//DATA IN REG 1
always @(posedge clk or negedge rst_n)
	if (!rst_n)				dat_in_r1 <= {(4*8){1'b0}};
	else if (op_i)			dat_in_r1 <= op_dat_i;
//DATA IN REG 2	
always @(posedge clk or negedge rst_n)
	if (!rst_n)				dat_in_r2 <= {(4*8){1'b0}};
	else if (rcv_run_r1)	dat_in_r2 <= dat_in_r1;
//DATA IN REG 3	
always @(posedge clk or negedge rst_n)
	if (!rst_n)				dat_in_r3 <= {(4*8){1'b0}};
	else if (rcv_run_r2)	dat_in_r3 <= dat_in_r2;
	
//TODO NEED CLR FLAG

//5E CHECK FLAG
//ONLY BYTE 0 CHECK |XX|XX|XX|5E|
always @(posedge clk or negedge rst_n)
	if (!rst_n)				flag_5E <= 1'b0;
	else if (rcv_run_r1)	flag_5E <= dat_in_r1[7:0] == 8'h5E;
	else						flag_5E <= 1'b0;

//5E4D CHECK(WIRE)
always @*
begin: FLAG_5E4D
	integer k;
	flag_5E4D = 1'b0;
	
	if (flag_5E & rcv_run_r1 & (dat_in_r1[31:24] == 8'h4D))
																	flag_5E4D = 1'b1;
	else if (rcv_run_r1) 
		for (k = 0; k < 3; k = k + 1)
			if (dat_in_r1[(8*k) +: 16] == 16'h5E4D)	flag_5E4D = 1'b1;
end

//FLAG 5E4D PTR REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)											flag_5E4D_r <= 1'b0;
	else if (trsmt_cmplt)							flag_5E4D_r <= 1'b0;
	else if (header_fix & !header_crc_true)	flag_5E4D_r <= 1'b0;
	else if (flag_5E4D)								flag_5E4D_r <= 1'b1;

//5E4D CHECK FLAG
/*integer i;
always @(posedge clk or negedge rst_n)
	if (!rst_n)																flag_5E4D <= 1'b0;
	else if (trsmt_cmplt)												flag_5E4D <= 1'b0;
	else if (header_fix & !header_crc_true)						flag_5E4D <= 1'b0;
	
	else if (flag_5E & !flag_5E4D & rcv_run_r1 & (dat_in_r1[31:24] == 8'h4D))
																				flag_5E4D <= 1'b1;
	else if (rcv_run_r1 & !flag_5E4D)
		for (i = 0; i < 3; i = i + 1)
				if (dat_in_r1[(8*i) +: 16] == 16'h5E4D)			flag_5E4D <= 1'b1;*/

//5E4D PTR
always @*
begin: PTR_5E4D
	integer j;
	flag_5E4D_ptr = 0;
	if (flag_5E & rcv_run_r1 & (dat_in_r1[31:24] == 8'h4D))
																				flag_5E4D_ptr = 3;
	else if (rcv_run_r1 & flag_5E4D)
		for (j = 0; j < 3; j = j + 1)
				if (dat_in_r1[(8*j) +: 16] == 16'h5E4D)			flag_5E4D_ptr = j;
	else
																				flag_5E4D_ptr = 0;
end
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																flag_5E4D_ptr_r <= 0;
	else if (trsmt_cmplt)												flag_5E4D_ptr_r <= 0;
	else if (header_fix & !header_crc_true)						flag_5E4D_ptr_r <= 0;
	else if (flag_5E4D)													flag_5E4D_ptr_r <= flag_5E4D_ptr;
				
				
/*always @(posedge clk or negedge rst_n)
	if (!rst_n)																flag_5E4D_ptr <= 0;
	else if (trsmt_cmplt)												flag_5E4D_ptr <= 0;
	else if (header_fix & !header_crc_true)						flag_5E4D_ptr <= 0;
																	
	else if (flag_5E & !flag_5E4D & rcv_run_r1 & (dat_in_r1[31:24] == 8'h4D))
																				flag_5E4D_ptr <= 3;
	else if (rcv_run_r1 & !flag_5E4D)
		for (j = 0; j < 3; j = j + 1)
				if (dat_in_r1[(8*j) +: 16] == 16'h5E4D)			flag_5E4D_ptr <= j;*/

//USB HEADER GRUB
always @(posedge clk or negedge rst_n)
	if (!rst_n)																											header_r <= {((4*8)){1'b0}};
	else if (trsmt_cmplt)																							header_r <= {((4*8)){1'b0}};
	//HEADER PART IN FIRST 32 BIT
	else if (flag_5E4D & rcv_run_r1 & (header_cnt == 0) & (flag_5E4D_ptr == 3) & !header_fix)	header_r[31: 8] <= dat_in_r1[23: 0];
	else if (flag_5E4D & rcv_run_r1 & (header_cnt == 0) & (flag_5E4D_ptr == 2) & !header_fix)	header_r[31:16] <= dat_in_r1[15: 0];
	else if (flag_5E4D & rcv_run_r1 & (header_cnt == 0) & (flag_5E4D_ptr == 1) & !header_fix)	header_r[31:24] <= dat_in_r1[ 7: 0];
	else if (flag_5E4D & rcv_run_r1 & (header_cnt == 0) & (flag_5E4D_ptr == 0) & !header_fix)	header_r[31: 0] <= {((4*8)){1'b0}};

	else if (flag_5E4D_r & rcv_run_r1 & (header_cnt == 5) & !header_fix)								header_r[ 7: 0] <= dat_in_r1[31:24];
	else if (flag_5E4D_r & rcv_run_r1 & (header_cnt == 4) & !header_fix)								header_r[15: 0] <= dat_in_r1[31:16];
	else if (flag_5E4D_r & rcv_run_r1 & (header_cnt == 3) & !header_fix)								header_r[23: 0] <= dat_in_r1[31: 8];
	else if (flag_5E4D_r & rcv_run_r1 & (header_cnt == 2) & !header_fix)								header_r[31: 0] <= dat_in_r1[31: 0];

//USB HEADER COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)															header_cnt <= 0;
	else if (trsmt_cmplt)											header_cnt <= 0;
	else if (header_fix & !header_crc_true)					header_cnt <= 0;
	else if (flag_5E4D & rcv_run_r1 & (header_cnt == 0))	header_cnt <= 2 + flag_5E4D_ptr;
	else if (flag_5E4D_r & rcv_run_r1)							header_cnt <= 6;
	
//USB HEADER FIX
always @(posedge clk or negedge rst_n)
	if (!rst_n)									header_fix <= 0;
	else if (trsmt_cmplt)					header_fix <= 0;
	else if (header_fix & !header_crc_true)
													header_fix <= 0;
	else if (flag_5E4D_r & rcv_run_r1 & (header_cnt >= 2))
													header_fix <= 1'b1;
													
always @(posedge clk or negedge rst_n)
	if (!rst_n)									header_fix_r <= 0;
	else if (trsmt_cmplt)					header_fix_r <= 0;
	else 											header_fix_r <= header_fix & header_crc_true;												

//USB HEADER ADDRESS
assign header_addr	= header_r[31:24];
//USB LENGTH HIGH
assign header_numh	= header_r[23:16];
//USB LENGTH LOW
assign header_numl	= header_r[15: 8];
//USB LENGTH CRC
assign header_crc		= header_r[ 7: 0];
	
//DATA LEN
assign data_len = {header_numh, header_numl};
	
//CALCULATED CRC(5E4D + ADDRESS)
crc8_ccitt crc8_h1
(
	.data_i		(		header_r[4*8-1 -: 8]		),
//CALCULATED CRC FOR 5E4D
	.crc_i		(		8'h3E							),  
	
	.crc_o		(		crc_ho1						)	
);

//CALCULATED CRC(CRC1 + PACKET LENGTH HIGH)
crc8_ccitt crc8_h2
(
	.data_i		(		header_r[3*8-1 -: 8]		),
	.crc_i		(		crc_ho1						),
	
	.crc_o		(		crc_ho2						)	
);
	
//CALCULATED CRC(CRC2 + PACKET LENGTH LOW)
crc8_ccitt crc8_h3
(
	.data_i		(		header_r[2*8-1 -: 8]		),
	.crc_i		(		crc_ho2						),
	
	.crc_o		(		crc_ho3						)	
);

//HEADER CRC CHECK
assign header_crc_true = header_crc == crc_ho3;

//-----------------------------------------------------------------------------------------------------------------------------
//DATA REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)																							data_r <= {((8*8)){1'b0}};
	else if (trsmt_cmplt)																			data_r <= {((8*8)){1'b0}};
	//LAST BYTES
//	else if (trsmt_cmplt & (flag_5E4D_ptr == 0))												data_r[8*8-1 : 0] <= {dat_in_r3[31: 0]  ,	{32{1'b0}}};
/*	else if (last_byte & (flag_5E4D_ptr == 0))												data_r[8*8-1 : 0] <= {							{64{1'b0}}};
	else if (last_byte & (flag_5E4D_ptr == 3))												data_r[8*8-1 : 0] <= {data_r[4*8-1 -:24], {40{1'b0}}};
	else if (last_byte & (flag_5E4D_ptr == 2))												data_r[8*8-1 : 0] <= {data_r[4*8-1 -:16], {48{1'b0}}};
	else if (last_byte & (flag_5E4D_ptr == 1))												data_r[8*8-1 : 0] <= {data_r[4*8-1 -: 8], {56{1'b0}}};*/
	
	//MIDDLE BYTES
	else if (header_fix_r & rcv_run_r3 & (flag_5E4D_ptr_r == 0))						data_r[8*8-1 : 0] <= {dat_in_r2[31: 0]  ,							{32{1'b0}}};	
	else if (header_fix_r & rcv_run_r3 & (flag_5E4D_ptr_r == 3))						data_r[8*8-1 : 0] <= {data_r[4*8-1 -:24], dat_in_r2[31: 0], {8 {1'b0}}};
	else if (header_fix_r & rcv_run_r3 & (flag_5E4D_ptr_r == 2))						data_r[8*8-1 : 0] <= {data_r[4*8-1 -:16], dat_in_r2[31: 0], {16{1'b0}}};
	else if (header_fix_r & rcv_run_r3 & (flag_5E4D_ptr_r == 1))						data_r[8*8-1 : 0] <= {data_r[4*8-1 -: 8], dat_in_r2[31: 0], {24{1'b0}}};
	
	//FIRST PART OF BYTES
//	else if (header_fix & rcv_run_r3 & (flag_5E4D_ptr_r == 0))							data_r[4*8-1 -: 32] <= dat_in_r2[31: 0];
	else if (header_fix & header_crc_true & rcv_run_r2 & (flag_5E4D_ptr_r == 3))	data_r[4*8-1 -: 24] <= dat_in_r2[23: 0];
	else if (header_fix & header_crc_true & rcv_run_r2 & (flag_5E4D_ptr_r == 2))	data_r[4*8-1 -: 16] <= dat_in_r2[15: 0];
	else if (header_fix & header_crc_true & rcv_run_r2 & (flag_5E4D_ptr_r == 1))	data_r[4*8-1 -:  8] <= dat_in_r2[7 : 0];
	
//DATA COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)																			data_cnt <= 0;
	else if (trsmt_cmplt)															data_cnt <= 0;
//	else if (header_fix & header_crc_true & rcv_run_r3)					data_cnt <= data_cnt + 4;
	else if (header_fix_r & rcv_run_r3)											data_cnt <= data_cnt + 4;
	
//LAST BYTE FLAG
assign last_byte = header_fix_r & (data_len < data_cnt + 4);

//DATA RUN SIGNAL
always @(posedge clk or negedge rst_n)
	if (!rst_n)																			data_run <= 1'b0;
	else if (data_cnt >= data_len)												data_run <= 1'b0;
	else if (header_fix & header_crc_true & rcv_run_r3 & (data_cnt != 0))
																							data_run <= 1'b1;
	else if (header_fix_r & rcv_run_r3 & (data_len <= flag_5E4D_ptr_r))
																							data_run <= 1'b1;

//TRANSMITION COMPLETE
assign trsmt_cmplt = header_fix_r & (data_cnt >= data_len + 1);

//CRC CHECK EN

	
//DATA BYTE ENABLE
always @(posedge clk or negedge rst_n)
	if (!rst_n)															byte_en <= 0;
	else if (header_fix & header_crc_true & rcv_run_r2 & (data_cnt == 0))	
																			byte_en <= 0;
	else if (header_fix & header_crc_true & rcv_run_r2 & ((data_len - data_cnt) <= 4))							
																			byte_en <= (data_len - data_cnt);
																			
//DATA CRC BYTE 1
crc8_ccitt crc8_d1
(
	.data_i		(		data_r[8*8-1 -: 8]		),
	.crc_i		(		data_crc_r					),
	
	.crc_o		(		crc_do1						)	
);

//DATA CRC BYTE 2
crc8_ccitt crc8_d2
(
	.data_i		(		data_r[8*7-1 -: 8]		),
	.crc_i		(		crc_do1						),
	
	.crc_o		(		crc_do2						)	
);

//DATA CRC BYTE 3
crc8_ccitt crc8_d3
(
	.data_i		(		data_r[8*6-1 -: 8]		),
	.crc_i		(		crc_do2						),
	
	.crc_o		(		crc_do3						)	
);

//DATA CRC BYTE 4
crc8_ccitt crc8_d4
(
	.data_i		(		data_r[8*5-1 -: 8]		),
	.crc_i		(		crc_do3						),
	
	.crc_o		(		crc_do4						)	
);
	
//CRC REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)				data_crc_r	 <= 0;
	else if (data_run)	data_crc_r	 <= crc_do4;

//OUTPUT SIGNALS
assign dat_en_o			= data_run;
assign dat_o				= data_r[8*8-1 :32];
assign dat_len_o			= data_len;
assign dat_be_o			= 2'b0; //TODO
assign dat_crc_true_o	= 1'b0; //TODO
assign dat_crc_chk_o		= 1'b0;
assign test_o				= flag_5E4D_ptr_r;

endmodule
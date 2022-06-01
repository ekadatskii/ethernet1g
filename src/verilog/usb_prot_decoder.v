module usb_prot_decoder (
	input						clk
	,input					rst_n
	,input					rcv_off
	
	,input					main_i
	,input					clr_i
	,output					run_o					
	
	,input					op_i			//Operation active
	,input	[31:0]		op_dat_i		//Operation data
	,input	[ 2:0]		op_be_i
	,input	[ 3:0]		be_decode_prev_i

	,output	[ 3:0]		be_decode_next_o
	,output					dat_en_o
	,output	[31:0]		dat_o
	,output	[15:0]		dat_len_o
	,output	[ 7:0]		dat_addr_o	
	,output	[ 2:0]		dat_be_o
	,output					dat_crc_chk_o
	,output					trsmt_cmplt_o
	
	,output					inc_chk_err_o
	,output					dat_crc_err_o
	,output	[1:0]			test_o
	,output					test2_o
	,output	[3:0]			test3_o
//	,input	[15:0]		tcp_data_len_i
);

reg					rcv_run_r1;
reg					rcv_run_r2;
reg					rcv_run_r3;
//reg					data_run;
reg	[(4*8)-1:0]	dat_in_r1;
reg	[(4*8)-1:0]	dat_in_r2;
reg	[(4*8)-1:0]	header_r;
reg	[ 3:0]		header_cnt;
reg					header_fix;
reg					header_fix_r;
reg	[ 7:0]		data_crc_r;
reg	[(8*8)-1:0]	data_r;
reg	[16:0]		wr_data_cnt;
reg	[16:0]		rd_data_cnt;
reg	[16:0]		packet_cnt;
reg	[ 3:0]		head_ptr;
reg	[ 3:0]		data_ptr;
reg	[ 3:0]		data_end_ptr;
reg	[ 2:0]		byte_en;
reg					crc_check_en;
reg					dat_crc_chk;
reg					last_byte_r;

reg					flag_5E;
reg					flag_5E_r;
reg					flag_5E4D;
reg					flag_5E4D_r;
reg	[1:0]			flag_5E4D_ptr;
reg	[1:0]			flag_5E4D_ptr_r;
reg	[3:0]			op_be_decode_r1;
reg	[3:0]			op_be_decode_r2;
reg	[2:0]			op_be_r1;
reg	[2:0]			op_be_r2;
reg					lock_r;

//TEST REGISTERS
reg	[31:0]		inc_cnt;
reg	[31:0]		inc_reg;

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
wire	[3:0]			op_be_decode;
wire	[15:0]		data_len;
wire	[7:0]			header_addr;
wire	[7:0]			header_numh;
wire	[7:0]			header_numl;
wire	[7:0]			header_crc;
wire					data_rd;
wire					lock;
wire					run;

//LOCK REGISTER TO CHANGE FLOW
always @(posedge clk or negedge rst_n)
	if (!rst_n)				lock_r <= !main_i;
	else if (rcv_off)		lock_r <= !main_i;
	else if (run)			lock_r <= 1'b1;
	else if (clr_i)		lock_r <= 1'b0;
	
assign lock = !clr_i & lock_r;
assign run	= flag_5E4D_r & op_i & !lock_r & ((packet_cnt + op_be_i >= data_len + 4 + 1) || ((header_cnt + op_be_i >= 4) & !header_crc_true));
assign be_decode_next_o =	(run & (header_cnt + op_be_i == 4)) ?	4'b0000 :
									(run & (header_cnt + op_be_i == 5)) ?	4'b0001 :
									(run & (header_cnt + op_be_i == 6)) ?	4'b0011 :
									(run & (header_cnt + op_be_i == 7)) ?	4'b0111 :
																						4'b1111;

//DATA RCV RUN REG 1
always @(posedge clk or negedge rst_n)
	if (!rst_n)				rcv_run_r1 <= 1'b0;
	else 						rcv_run_r1 <= op_i;

//DATA IN REG 1
always @(posedge clk or negedge rst_n)
	if (!rst_n)				dat_in_r1 <= {(4*8){1'b0}};
	else if (op_i)			dat_in_r1 <= op_dat_i;
	
//BE DECODER
assign op_be_decode =	(op_be_i == 4) ? 4'b1111 :
								(op_be_i == 3) ? 4'b1110 :
								(op_be_i == 2) ? 4'b1100 :
								(op_be_i == 1) ? 4'b1000 : 4'b0000;
	
//BE DECODER 1
always @(posedge clk or negedge rst_n)
	if (!rst_n)		op_be_decode_r1 <= 4'b0;
	else if (op_i)	op_be_decode_r1 <= op_be_decode; 
	
//BE REG 1
always @(posedge clk or negedge rst_n)
	if (!rst_n)		op_be_r1 <= 0;
	else if (op_i)	op_be_r1 <= op_be_i;	

//5E HIT FLAG
always @*
begin: FLAG_5E
	integer i;
	flag_5E = 1'b0;
	
	if (op_i & !lock)
		for (i = 3; i >= 0; i = i - 1)
			if (op_be_decode[i] & be_decode_prev_i[i])	
			begin
				flag_5E = (op_dat_i[(8*i) +: 8] == 8'h5E);
			end
end

//5E CHECK FLAG REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)											flag_5E_r <= 1'b0;
	else if (rcv_off)									flag_5E_r <= 1'b0;
	else if (trsmt_cmplt)							flag_5E_r <= 1'b0;
	else if (header_fix & !header_crc_true)	flag_5E_r <= 1'b0;
	else if (op_i)										flag_5E_r <= flag_5E;

//5E4D HIT FLAG + PTR (WIRE)
always @*
begin: FLAG_5E4D
	integer k;
	flag_5E4D = 1'b0;
	flag_5E4D_ptr = 2'd0;
	
	if (flag_5E_r & op_i & !lock & (op_dat_i[31:24] == 8'h4D) & op_be_decode[3])
	begin
					flag_5E4D = 1'b1;
					flag_5E4D_ptr = 3;
	end
	else if (op_i & !lock) 
		for (k = 0; k < 3; k = k + 1)
			if ((op_dat_i[(8*k) +: 16] == 16'h5E4D) & ((op_be_decode[k +: 2]) == 2'b11) & ((be_decode_prev_i[k +: 2]) == 2'b11))
			begin
					flag_5E4D = 1'b1;
					flag_5E4D_ptr = k;
			end
end

//FLAG 5E4D PTR REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)											flag_5E4D_r <= 1'b0;
	else if (rcv_off)									flag_5E4D_r <= 1'b0;	
	else if (trsmt_cmplt)							flag_5E4D_r <= 1'b0;
	else if (header_fix & !header_crc_true)	flag_5E4D_r <= 1'b0;
	else if (flag_5E4D & op_i)						flag_5E4D_r <= 1'b1;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																flag_5E4D_ptr_r <= 0;
	else if (rcv_off)														flag_5E4D_ptr_r <= 0;		
	else if (trsmt_cmplt)												flag_5E4D_ptr_r <= 0;
	else if (header_fix & !header_crc_true)						flag_5E4D_ptr_r <= 0;
	else if (flag_5E4D & op_i)											flag_5E4D_ptr_r <= flag_5E4D_ptr;

//USB HEADER GRUB
always @(posedge clk or negedge rst_n)
	if (!rst_n)																											header_r <= {((4*8)){1'b0}};
	else if (trsmt_cmplt)																							header_r <= {((4*8)){1'b0}};
	
	//HEADER PART IN FIRST 32 BIT
	else if (flag_5E4D_r & op_i & (header_cnt == 0) & !header_fix)
	begin
		if (op_be_decode[3]) header_r[31:24] <= op_dat_i[31:24];
		if (op_be_decode[2]) header_r[23:16] <= op_dat_i[23:16];
		if (op_be_decode[1]) header_r[15: 8] <= op_dat_i[15: 8];
		if (op_be_decode[0]) header_r[ 7: 0] <= op_dat_i[ 7: 0];
	end
	else if (flag_5E4D_r & op_i & (header_cnt == 1) & !header_fix)								
	begin
		if (op_be_decode[3]) header_r[23:16] <= op_dat_i[31:24];
		if (op_be_decode[2]) header_r[15: 8] <= op_dat_i[23:16];
		if (op_be_decode[1]) header_r[ 7: 0] <= op_dat_i[15: 8];
	end
	else if (flag_5E4D_r & op_i & (header_cnt == 2) & !header_fix)								
	begin
		if (op_be_decode[3]) header_r[15: 8] <= op_dat_i[31:24];
		if (op_be_decode[2]) header_r[ 7: 0] <= op_dat_i[23:16];
	end
	else if (flag_5E4D_r & op_i & (header_cnt == 3) & !header_fix)								
	begin
		if (op_be_decode[3]) header_r[ 7: 0] <= op_dat_i[31:24];
	end
	
	//5E4D AND HEADER IN SAME 32 BIT
	else if (flag_5E4D & op_i & (flag_5E4D_ptr == 3) & !header_fix)	
	begin	
			if (op_be_decode[2]) header_r[31:24] <= op_dat_i[23:16];
			if (op_be_decode[1]) header_r[23:16] <= op_dat_i[15: 8];
			if (op_be_decode[0]) header_r[15: 8] <= op_dat_i[ 7: 0];
	end
	
	else if (flag_5E4D & op_i & (flag_5E4D_ptr == 2) & !header_fix)
	begin
			if (op_be_decode[1]) header_r[31:24] <= op_dat_i[15: 8];
			if (op_be_decode[0]) header_r[23:16] <= op_dat_i[ 7: 0];
	end
	
	else if (flag_5E4D & op_i & (flag_5E4D_ptr == 1) & !header_fix)
	begin
			if (op_be_decode[0]) header_r[31:24] <= op_dat_i[ 7: 0];
	end
	
//USB HEADER COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)															header_cnt <= 0;
	else if (trsmt_cmplt)											header_cnt <= 0;
	else if (rcv_off)													header_cnt <= 0;
	else if (header_fix & !header_crc_true)					header_cnt <= 0;
	else if (flag_5E4D_r & op_i & !header_fix)				header_cnt <= header_cnt + op_be_i;
	else if (flag_5E4D & op_i)										header_cnt <= header_cnt + op_be_i - (4 - flag_5E4D_ptr);
	
//PACKET COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)															packet_cnt <= 0;
	else if (trsmt_cmplt)											packet_cnt <= 0;
	else if (rcv_off)													packet_cnt <= 0;	
	else if (header_fix & !header_crc_true)					packet_cnt <= 0;
	else if (flag_5E4D_r & op_i)									packet_cnt <= packet_cnt + op_be_i;
	else if (flag_5E4D & op_i)										packet_cnt <= packet_cnt + op_be_i - (4 - flag_5E4D_ptr);
	
//HEADER PTR(HEADER ENDS AND DATA STARTS)
always @(posedge clk or negedge rst_n)
	if (!rst_n)																									head_ptr <= 4'b0;
	else if (trsmt_cmplt)																					head_ptr <= 4'b0;
	else if (rcv_off)																							head_ptr <= 4'b0;		
	else if (flag_5E4D_r & op_i & !header_fix & !header_fix_r & (header_cnt < 4))			head_ptr <= 4 - header_cnt;


//USB HEADER FIX
always @(posedge clk or negedge rst_n)
	if (!rst_n)									header_fix <= 0;
	else if (trsmt_cmplt)					header_fix <= 0;
	else if (rcv_off)							header_fix <= 0;			
	else if (header_fix & !header_crc_true)
													header_fix <= 0;
	else if (flag_5E4D_r & op_i & ((header_cnt + op_be_i) >= 4))
													header_fix <= 1'b1;
													
always @(posedge clk or negedge rst_n)
	if (!rst_n)										header_fix_r <= 0;
	else if (trsmt_cmplt)						header_fix_r <= 0;
	else if (rcv_off)								header_fix_r <= 0;
	else if (header_fix & header_crc_true)	header_fix_r <= 1;												

//USB HEADER ADDRESS
assign header_addr	= (header_cnt >= 1) ? header_r[31:24] :	op_dat_i[31:24];
//USB LENGTH HIGH
assign header_numh	= (header_cnt >= 2) ? header_r[23:16] :	(header_cnt == 0) ? op_dat_i[23:16] : op_dat_i[31:24];
//USB LENGTH LOW
assign header_numl	= (header_cnt >= 3) ? header_r[15: 8] :	(header_cnt == 0) ? op_dat_i[15: 8] : 
																					(header_cnt == 1) ? op_dat_i[23:16] : op_dat_i[31:24];
//USB LENGTH CRC
assign header_crc		= (header_cnt >= 4) ? header_r[ 7: 0] :	(header_cnt == 0) ? op_dat_i[ 7: 0] : 
																					(header_cnt == 1) ? op_dat_i[15: 8] : 
																					(header_cnt == 2) ? op_dat_i[23:16] : op_dat_i[31:24];
	
//DATA LEN
assign data_len = {header_numh, header_numl};
	
//CALCULATED CRC(5E4D + ADDRESS)
crc8_ccitt crc8_h1
(
	.data_i		(		header_addr					),
//CALCULATED CRC FOR 5E4D
	.crc_i		(		8'h3E							),  
	
	.crc_o		(		crc_ho1						)	
);

//CALCULATED CRC(CRC1 + PACKET LENGTH HIGH)
crc8_ccitt crc8_h2
(
	.data_i		(		header_numh					),
	.crc_i		(		crc_ho1						),
	
	.crc_o		(		crc_ho2						)	
);
	
//CALCULATED CRC(CRC2 + PACKET LENGTH LOW)
crc8_ccitt crc8_h3
(
	.data_i		(		header_numl					),
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
	
	//LAST BYTES OF DATA
	else if (last_byte)
	begin
		if (data_ptr == 3)
		begin 
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
		end	
		else if (data_ptr == 2)
		begin 
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
											data_r[(7          )*8-1 -: 8] <= data_r[3*8-1 -: 8];											
		end	
		else if (data_ptr == 1)
		begin 
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
											data_r[(7          )*8-1 -: 8] <= data_r[3*8-1 -: 8];
											data_r[(6          )*8-1 -: 8] <= data_r[2*8-1 -: 8];
		end
	end
	
	//MIDDLE BYTES OF DATA
	else if (header_fix_r & rcv_run_r1)
	begin	
		if (data_ptr == 8)
		begin 
			if (op_be_decode_r1[3]) data_r[(data_ptr   )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(data_ptr -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(data_ptr -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(data_ptr -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
		end
		else if (data_ptr == 7)
		begin 
			if (op_be_decode_r1[3]) data_r[(data_ptr   )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(data_ptr -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(data_ptr -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(data_ptr -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
		end
		else if (data_ptr == 6)
		begin 
			if (op_be_decode_r1[3]) data_r[(data_ptr   )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(data_ptr -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(data_ptr -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(data_ptr -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
		end
		else if (data_ptr == 5)
		begin 										
			if (op_be_decode_r1[3]) data_r[(data_ptr   )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(data_ptr -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(data_ptr -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(data_ptr -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
		end
		else if (data_ptr == 4)
		begin 
			if (op_be_decode_r1[3]) data_r[(8          )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(8        -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(8        -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(8        -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
		end	
		else if (data_ptr == 3)
		begin 
			if (op_be_decode_r1[3]) data_r[(7          )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(7        -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(7        -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(7        -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
		end	
		else if (data_ptr == 2)
		begin 
			if (op_be_decode_r1[3]) data_r[(6          )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(6        -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(6        -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(6        -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
											data_r[(7          )*8-1 -: 8] <= data_r[3*8-1 -: 8];											
		end	
		else if (data_ptr == 1)
		begin 
			if (op_be_decode_r1[3]) data_r[(5          )*8-1 -: 8] <= dat_in_r1[31:24];
			if (op_be_decode_r1[2]) data_r[(5        -1)*8-1 -: 8] <= dat_in_r1[23:16];
			if (op_be_decode_r1[1]) data_r[(5        -2)*8-1 -: 8] <= dat_in_r1[15: 8];
			if (op_be_decode_r1[0]) data_r[(5        -3)*8-1 -: 8] <= dat_in_r1[ 7: 0];
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
											data_r[(7          )*8-1 -: 8] <= data_r[3*8-1 -: 8];
											data_r[(6          )*8-1 -: 8] <= data_r[2*8-1 -: 8];
		end	
	end

	//MIDDLE BYTES (ONLY READ OPERATION)
	else if (header_fix_r & data_rd)
	begin
		if (data_ptr == 3)
		begin 
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
		end
		else if (data_ptr == 2)
		begin 
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
											data_r[(7          )*8-1 -: 8] <= data_r[3*8-1 -: 8];	
		end
		else if (data_ptr == 1)
		begin 
											data_r[(8          )*8-1 -: 8] <= data_r[4*8-1 -: 8];
											data_r[(7          )*8-1 -: 8] <= data_r[3*8-1 -: 8];
											data_r[(6          )*8-1 -: 8] <= data_r[2*8-1 -: 8];											
		end
		
	end
	
	//FIRST BYTES OF DATA
	else if (header_fix & header_crc_true & rcv_run_r1 & (head_ptr == 1))
	begin	
		if (op_be_decode_r1[2]) data_r[8*8-1 -: 8] <= dat_in_r1[23:16];
		if (op_be_decode_r1[1]) data_r[7*8-1 -: 8] <= dat_in_r1[15: 8];
		if (op_be_decode_r1[0]) data_r[6*8-1 -: 8] <= dat_in_r1[ 7: 0];
	end
	else if (header_fix & header_crc_true & rcv_run_r1 & (head_ptr == 2))
	begin	
		if (op_be_decode_r1[1]) data_r[8*8-1 -: 8] <= dat_in_r1[15: 8];
		if (op_be_decode_r1[0]) data_r[7*8-1 -: 8] <= dat_in_r1[ 7: 0];
	end
	else if (header_fix & header_crc_true & rcv_run_r1 & (head_ptr == 3))
	begin	
		if (op_be_decode_r1[0]) data_r[8*8-1 -: 8] <= dat_in_r1[ 7: 0];
	end
	
//WRITE DATA COUNTER																																					
always @(posedge clk or negedge rst_n)
	if (!rst_n)																											wr_data_cnt <= 0;
	else if (trsmt_cmplt)																							wr_data_cnt <= 0;
	else if (rcv_off)																									wr_data_cnt <= 0;	
	else if (header_fix_r & rcv_run_r1 & (data_len + 1 >= wr_data_cnt))								wr_data_cnt <= wr_data_cnt + op_be_r1;
	else if (header_fix & !header_fix_r & header_crc_true & rcv_run_r1 & (header_cnt == 7))	wr_data_cnt <= wr_data_cnt + 3;
	else if (header_fix & !header_fix_r & header_crc_true & rcv_run_r1 & (header_cnt == 6))	wr_data_cnt <= wr_data_cnt + 2;
	else if (header_fix & !header_fix_r & header_crc_true & rcv_run_r1 & (header_cnt == 5))	wr_data_cnt <= wr_data_cnt + 1;
	
//READ DATA COUNTER																																					
always @(posedge clk or negedge rst_n)
	if (!rst_n)																						rd_data_cnt <= 0;
	else if (trsmt_cmplt)																		rd_data_cnt <= 0;
	else if (rcv_off)																				rd_data_cnt <= 0;		
	else if (header_fix_r & data_rd)															rd_data_cnt <= rd_data_cnt + 4;
	
//DATA PTR																																	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																											data_ptr <= 4'd8;
	else if (trsmt_cmplt)																							data_ptr <= 4'd8;
	else if (rcv_off)																									data_ptr <= 4'd8;
	else if (header_fix_r & rcv_run_r1 & (data_len + 1 >= wr_data_cnt))								data_ptr <= data_ptr - op_be_r1 + 4*data_rd;
	else if (header_fix_r & !rcv_run_r1 & data_rd)															data_ptr <= data_ptr + 4;
	else if (header_fix & !header_fix_r & header_crc_true & rcv_run_r1 & (header_cnt == 7))	data_ptr <= data_ptr - 3;
	else if (header_fix & !header_fix_r & header_crc_true & rcv_run_r1 & (header_cnt == 6))	data_ptr <= data_ptr - 2;
	else if (header_fix & !header_fix_r & header_crc_true & rcv_run_r1 & (header_cnt == 5))	data_ptr <= data_ptr - 1;


//DATA READ
assign data_rd = ((wr_data_cnt - rd_data_cnt) >= 4) | last_byte;

//LAST BYTE FLAG
assign last_byte = (data_len + 1 <= wr_data_cnt);

//TRANSMITION COMPLETE
assign trsmt_cmplt = header_fix_r & data_rd & (data_len + 1 <= rd_data_cnt + 4) & last_byte; 

//CRC CHECK EN

	
//DATA BYTE ENABLE
always @*
begin
	byte_en = 0;
	if (data_rd & (data_len >= (rd_data_cnt + 4))) 				byte_en = 4;
	else if (data_rd & ((rd_data_cnt + 4 - data_len) == 1))	byte_en = 3;
	else if (data_rd & ((rd_data_cnt + 4 - data_len) == 2))	byte_en = 2;
	else if (data_rd & ((rd_data_cnt + 4 - data_len) == 3))	byte_en = 1;
end
	
																			
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
	if (!rst_n)					data_crc_r	 <= 0;
	else if (trsmt_cmplt)	data_crc_r	 <= 0;
	else if (rcv_off)			data_crc_r	 <= 0;
	else if (data_rd)			data_crc_r	 <= crc_do4;

//DATA CRC CHECK
assign data_crc_chk = trsmt_cmplt ?	((byte_en == 0) ? (data_crc_r == data_r[8*8-1 -: 8]) : 
												 (byte_en == 1) ? (crc_do1 	== data_r[8*7-1 -: 8]) : 
												 (byte_en == 2) ? (crc_do2 	== data_r[8*6-1 -: 8]) : 
												 (byte_en == 3) ? (crc_do3 	== data_r[8*5-1 -: 8]) : 1'b0)
												: 1'b0;

//TEST REGISTERS
always @(posedge clk or negedge rst_n)
	if (!rst_n)											inc_cnt <= 0;
	else if (rcv_off)									inc_cnt <= 0;	
	else if (trsmt_cmplt)							inc_cnt <= inc_cnt + 1;

always @(posedge clk or negedge rst_n)
	if (!rst_n)											inc_reg <= 0;
	else if (rcv_off)									inc_reg <= 0;
	else if ((rd_data_cnt == 4) & data_rd)		inc_reg <= dat_o;

//OUTPUT SIGNALS
assign dat_en_o			= data_rd;
assign dat_o				= data_r[8*8-1 :32];
assign dat_len_o			= data_len;
assign dat_addr_o			= header_addr;
assign dat_be_o			= byte_en;
assign dat_crc_chk_o		= data_crc_chk;
assign test_o				= flag_5E4D_ptr_r;
assign test2_o				= last_byte;
assign test3_o				= head_ptr;
assign dat_crc_err_o		= trsmt_cmplt & !data_crc_chk;
assign inc_chk_err_o		= trsmt_cmplt & (inc_reg != inc_cnt);
assign run_o				= run;
assign trsmt_cmplt_o		= trsmt_cmplt;
assign dat_be_next_o		= 4'b0;

endmodule
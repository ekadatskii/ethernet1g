module transport_layer
(
	input					clk
	,input				rst_n
	,input	[31:0]	dev_ip_addr_i

	,input				rcv_op_st_i
	,input				rcv_op_i
	,input				rcv_op_end_i
	,input	[31:0]	rcv_data_i
	,input	[15:0]	rcv_data_len_i
	,input	[31:0]	src_ip_addr_i
	,input	[31:0]	dst_ip_addr_i
	,input	[7:0]		prot_type_i
	,input	[15:0]	pseudo_crc_sum_i
	


	,output	[15:0]	source_port_o
	,output	[15:0]	dest_port_o
	,output	[15:0]	data_length_o
	,output	[31:0]	seq_num_o
	,output	[31:0]	ack_num_o
	,output	[5 :0]	tcp_flags_o		
	,output	[95:0]	options_o
	,output	[ 3:0]	tcp_head_len_o
	,output	[15:0]	tcp_window_o

	,output				upper_op_st
	,output				upper_op
	,output				upper_op_end
	,output	[31:0]	upper_data
	,output	[ 1:0]	upper_data_be
	,output	[15:0]	crc_sum_o
	,output				crc_check_o
		
	,output	[15:0]	test_word_cnt
);
parameter	OPTIONS_SIZE = 4'd4;

//TCP OR UDP FIELDS
reg	[15:0]	source_port;
reg	[15:0]	dest_port;
reg	[31:0]	seq_num;
reg	[31:0]	ack_num;
reg	[ 3:0]	tcp_head_len;
reg	[ 5:0]	tcp_flags;
reg	[15:0]	tcp_window;
reg	[15:0]	packet_length;
reg	[15:0]	checksum;
reg	[15:0]	urgent_ptr;

reg	[32*OPTIONS_SIZE -1 :0]	options_reg;

reg	[15:0]	word_cnt;
reg	[15:0]	data_word_cnt;

reg				upper_op_start_r;
reg				upper_op_r;
reg				upper_op_stop_r;
reg	[31:0]	upper_data_r;
reg	[ 1:0]	data_be_r;

reg	[31:0]	crc_dat_r;

wire	[31:0]	crc_head_w;
wire	[31:0]	crc_head_ww;
wire	[15:0]	crc_head_www;
wire	[31:0]	crc_dat;
wire	[31:0]	crc_dat_w;
wire	[31:0]	crc_dat_ww;
wire	[15:0]	crc_dat_www;
wire	[31:0]	crc_sum_w;
wire	[31:0]	crc_sum_ww;
wire	[15:0]	crc_sum_www;

wire	[ 1:0]	data_be;
wire	[15:0]	data_length;

wire				rcv_op_st;
wire				rcv_op;
wire				rcv_op_end;
wire	[31:0]	rcv_data;
wire	[15:0]	rcv_data_len;
wire	[15:0]	pseudo_crc_sum;
wire				tcp_prot;
wire				ip_check;

//PROTOCOL AND DESTINATION IP ADDRESS CHECK
assign tcp_prot = prot_type_i == 8'd06;
assign ip_check = dev_ip_addr_i == dst_ip_addr_i;

//INPUT CONTROL SIGNALS AFTER IP ADDRESS FILTER
assign rcv_op				= rcv_op_i 		& tcp_prot & ip_check;
assign rcv_op_st			= rcv_op_st_i	& tcp_prot & ip_check;
assign rcv_op_end			= rcv_op_end_i	& tcp_prot & ip_check;
assign rcv_data			= (tcp_prot & ip_check) ? rcv_data_i 			: {32{1'b0}};
assign rcv_data_len		= (tcp_prot & ip_check) ? rcv_data_len_i		: {16{1'b0}};
assign pseudo_crc_sum	= (tcp_prot & ip_check) ? pseudo_crc_sum_i	: {16{1'b0}};

always @(posedge clk or negedge rst_n)
	if (!rst_n) 						word_cnt <= 16'b0;
	else if (rcv_op_end)				word_cnt <= 16'b0;
	else if (rcv_op & tcp_prot)	word_cnt <= word_cnt + 1'b1;

//TCP OR UDP FIELDS
//-------------------------------------------------------------------------------
//VERSION NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												source_port <= 16'b0;
	else if (rcv_op_st & rcv_op)							source_port <= rcv_data[31:16];
	
//DESTINATION PORT
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												dest_port <= 16'b0;
	else if (rcv_op_st & rcv_op)							dest_port <= rcv_data[15:0];
	
//PACKET LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												packet_length <= 16'b0;
	else if (rcv_op_st & rcv_op)							packet_length <= rcv_data_len;
	
//SEQUENCE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												seq_num <= 32'b0;
	else if (rcv_op & (word_cnt == 1) )					seq_num <= rcv_data;

//ACKNOWLEDGE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												ack_num <= 32'b0;
	else if (rcv_op & (word_cnt == 2))					ack_num <= rcv_data;
	
//TCP HEADER LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												tcp_head_len <= 4'b0;
	else if (rcv_op & (word_cnt == 3))					tcp_head_len <= rcv_data[31:28];
	
//TCP FLAGS
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												tcp_flags <= 6'b0;
	else if (rcv_op & (word_cnt == 3))					tcp_flags <= rcv_data[21:16];
	
//TCP WINDOW
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												tcp_window <= 16'b0;
	else if (rcv_op & (word_cnt == 3))					tcp_window <= rcv_data[15:0];
	
//CHECKSUM
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												checksum <= 16'b0;
	else if (rcv_op & (word_cnt == 4))					checksum <= rcv_data[31:16];
	
//URGENT POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												urgent_ptr <= 16'b0;
	else if (rcv_op & (word_cnt == 4))					urgent_ptr <= rcv_data[15:0];
	
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												options_reg <= {(32*OPTIONS_SIZE){1'b0}};
	else if (rcv_op_st & rcv_op)							options_reg <= {(32*OPTIONS_SIZE){1'b0}};
	else if (rcv_op & (word_cnt == 5) & (word_cnt < tcp_head_len))
																	options_reg[31:0] <= rcv_data;
	else if (rcv_op & (word_cnt == 6) & (word_cnt < tcp_head_len))
																	options_reg[63:32] <= rcv_data;
	else if (rcv_op & (word_cnt == 7) & (word_cnt < tcp_head_len))
																	options_reg[95:64] <= rcv_data;
	else if (rcv_op & (word_cnt == 8) & (word_cnt < tcp_head_len))
																	options_reg[127:96] <= rcv_data;
	


//CRC HEADER
assign crc_head_w =	source_port + dest_port + seq_num[31:16] + seq_num[15:0] + ack_num[31:16] + ack_num[15:0] + 
							{tcp_head_len, 6'b0, tcp_flags} + tcp_window + checksum + urgent_ptr; 

assign crc_head_ww = crc_head_w[31:16] + crc_head_w[15:0];
assign crc_head_www = crc_head_ww[31:16] + crc_head_ww[15:0];

//TCP OR UDP DATA
//-------------------------------------------------------------------------------
//RECEIVE DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_data_r <= 32'b0;
	else if (rcv_op & (word_cnt >= 5) & (word_cnt >= tcp_head_len) & ((word_cnt << 2) < packet_length))
																	upper_data_r <= rcv_data;
	else 															upper_data_r <= 32'b0;

//START TCP OR UDP DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_op_start_r <= 1'b0;
	else if (upper_op_start_r)								upper_op_start_r <= 1'b0;
	else if (rcv_op & (word_cnt == tcp_head_len) & (packet_length > (tcp_head_len * 4)))
																	upper_op_start_r <= 1'b1;
								
//STOP TCP OR UDP DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_op_stop_r <= 1'b0;
	else if (upper_op_stop_r)								upper_op_stop_r <= 1'b0;
	else if (rcv_op & (word_cnt >= 4) & ((word_cnt + 1 << 2) >= packet_length) & ((word_cnt << 2) < packet_length))	
																	upper_op_stop_r <= 1'b1;

//RECEIVE DATA OPERATION
always @(posedge clk or negedge rst_n)
	if (!rst_n)													upper_op_r <= 1'b0;																	
	else if (rcv_op & (word_cnt >= 5) & (word_cnt >= tcp_head_len) & ((word_cnt << 2) < packet_length))
																	upper_op_r <= 1'b1;																
	else 															upper_op_r <= 1'b0;
																												
//DATA CRC
always @(posedge clk or negedge rst_n)
	if (!rst_n)													crc_dat_r <= 32'b0;
	else if (rcv_op & rcv_op_st)							crc_dat_r <= 32'b0;
	else if (rcv_op & (word_cnt >= 5) & ((word_cnt << 2) < packet_length))
																	crc_dat_r <= crc_dat;

assign crc_dat   =	(data_be == 2'b00) ? crc_dat_r +  rcv_data[31:16] +  rcv_data[15:0]			:
							(data_be == 2'b11) ? crc_dat_r +  rcv_data[31:16] + {rcv_data[15:8], 8'b0}	:
							(data_be == 2'b10) ? crc_dat_r +  rcv_data[31:16] 									:
							(data_be == 2'b01) ? crc_dat_r + {rcv_data[31:24], 8'b0}							: 32'b0;

assign crc_dat_w   = crc_dat_r [31:16] + crc_dat_r [15:0];						
assign crc_dat_ww  = crc_dat_w [31:16] + crc_dat_w [15:0];
assign crc_dat_www = crc_dat_ww[31:16] + crc_dat_ww[15:0];

//CRC SUMMARY
assign crc_sum_w   = crc_head_www + crc_dat_www + pseudo_crc_sum;
assign crc_sum_ww  = crc_sum_w [31:16] + crc_sum_w [15:0];
assign crc_sum_www = crc_sum_ww[31:16] + crc_sum_ww[15:0];

//DATA LENGTH
assign data_length = packet_length - (tcp_head_len * 4);

//BYTE ENABLE
assign data_be = (((packet_length - (word_cnt << 2)) == 3) ? 2'b11 :
						((packet_length - (word_cnt << 2)) == 2) ? 2'b10 :
						((packet_length - (word_cnt << 2)) == 1) ? 2'b01 : 2'b00);
						
//BYTE ENABLE REG					
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												data_be_r <= 2'b0;
	else if (rcv_op & (word_cnt >= 5) & (word_cnt >= tcp_head_len) & ((word_cnt << 2) < packet_length))
																	data_be_r <= data_be;
	else 															data_be_r <= 2'b0;

//INOUTS
assign source_port_o		= source_port;
assign dest_port_o		= dest_port;
assign data_length_o		= packet_length;
assign crc_sum_o			= crc_sum_www;
assign crc_check_o		= crc_sum_www == 16'hFFFF;

assign upper_op_st		= upper_op_start_r;
assign upper_op			= upper_op_r;
assign upper_op_end		= upper_op_stop_r;
assign upper_data			= upper_data_r;
assign upper_data_be		= data_be_r;


assign seq_num_o			= seq_num;
assign ack_num_o			= ack_num;
assign tcp_flags_o		= tcp_flags;
assign tcp_head_len_o	= tcp_head_len;
assign options_o			= options_reg[95:0];
assign tcp_window_o		= tcp_window;

assign test_word_cnt		= word_cnt << 2;



endmodule
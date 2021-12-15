module transport_layer
(
	input					clk
	,input				rst_n

	,input				rcv_op_st
	,input				rcv_op
	,input				rcv_op_end
	,input	[31:0]	rcv_data
	,input	[15:0]	rcv_data_len
	,input	[7:0]		prot_type
	,input	[15:0]	pseudo_crc_sum
	


	,output	[15:0]	source_port_o
	,output	[15:0]	dest_port_o
	,output	[15:0]	packet_length_o
	,output	[15:0]	checksum_o
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
	,output	[15:0]	crc_sum_o
	

);
parameter	OPTIONS_SIZE = 4'd4;

//UDP FIELDS
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

reg	[31:0]	crc_dat_r;

wire	[31:0]	crc_head_w;
wire	[31:0]	crc_head_ww;
wire	[15:0]	crc_head_www;
wire	[31:0]	crc_dat_w;
wire	[31:0]	crc_dat_ww;
wire	[15:0]	crc_dat_www;
wire	[31:0]	crc_sum_w;
wire	[31:0]	crc_sum_ww;
wire	[15:0]	crc_sum_www;

assign tcp_prot = prot_type == 8'd06;

always @(posedge clk or negedge rst_n)
	if (!rst_n) 						word_cnt <= 16'b0;
	else if (rcv_op_end)				word_cnt <= 16'b0;
	else if (rcv_op & tcp_prot)	word_cnt <= word_cnt + 1'b1;

//UDP FIELDS
//-------------------------------------------------------------------------------
//VERSION NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												source_port <= 16'b0;
	else if (rcv_op_st & rcv_op & tcp_prot)			source_port <= rcv_data[31:16];
	
//DESTINATION PORT
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												dest_port <= 16'b0;
	else if (rcv_op_st & rcv_op & tcp_prot)			dest_port <= rcv_data[15:0];
	
//PACKET LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												packet_length <= 16'b0;
	else if (rcv_op_st & rcv_op & tcp_prot)			packet_length <= rcv_data_len;
	
//SEQUENCE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												seq_num <= 32'b0;
	else if (rcv_op & (word_cnt == 1) & tcp_prot)	seq_num <= rcv_data;

//ACKNOWLEDGE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												ack_num <= 32'b0;
	else if (rcv_op & (word_cnt == 2) & tcp_prot)	ack_num <= rcv_data;
	
//TCP HEADER LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												tcp_head_len <= 4'b0;
	else if (rcv_op & (word_cnt == 3) & tcp_prot)	tcp_head_len <= rcv_data[31:28];
	
//TCP FLAGS
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												tcp_flags <= 6'b0;
	else if (rcv_op & (word_cnt == 3) & tcp_prot)	tcp_flags <= rcv_data[21:16];
	
//TCP WINDOW
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												tcp_window <= 16'b0;
	else if (rcv_op & (word_cnt == 3) & tcp_prot)	tcp_window <= rcv_data[15:0];
	
//CHECKSUM
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												checksum <= 16'b0;
	else if (rcv_op & (word_cnt == 4) & tcp_prot)	checksum <= rcv_data[31:16];
	
//URGENT POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												urgent_ptr <= 16'b0;
	else if (rcv_op & (word_cnt == 4) & tcp_prot)	urgent_ptr <= rcv_data[15:0];
	
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												options_reg <= {(32*OPTIONS_SIZE){1'b0}};
	else if (rcv_op_st & rcv_op)							options_reg <= {(32*OPTIONS_SIZE){1'b0}};
	else if (rcv_op & (word_cnt == 5) & (word_cnt < tcp_head_len) & tcp_prot)
																	options_reg[31:0] <= rcv_data;
	else if (rcv_op & (word_cnt == 6) & (word_cnt < tcp_head_len) & tcp_prot)
																	options_reg[63:32] <= rcv_data;
	else if (rcv_op & (word_cnt == 7) & (word_cnt < tcp_head_len) & tcp_prot)
																	options_reg[95:64] <= rcv_data;
	else if (rcv_op & (word_cnt == 8) & (word_cnt < tcp_head_len) & tcp_prot)
																	options_reg[127:96] <= rcv_data;
/*	else if (rcv_op & (word_cnt >= 5) & (word_cnt < tcp_head_len) & tcp_prot)	
																	options_reg[31 * (word_cnt - 4'd5) +: 32] <= rcv_data;*/
	


//CRC HEADER
assign crc_head_w = source_port + dest_port + seq_num[31:16] + seq_num[15:0] + ack_num[31:16] + ack_num[15:0] + {tcp_head_len, 6'b0, tcp_flags} + tcp_window + checksum + urgent_ptr;
assign crc_head_ww = crc_head_w[31:16] + crc_head_w[15:0];
assign crc_head_www = crc_head_ww[31:16] + crc_head_ww[15:0];

//UDP DATA
//-------------------------------------------------------------------------------
//RECEIVE DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_data_r <= 32'b0;
	else if (rcv_op & tcp_prot & (word_cnt >= 5) & (word_cnt >= tcp_head_len))	
																	upper_data_r <= rcv_data;
	else 															upper_data_r <= 32'b0;
	
//UDP DATA WORD COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												data_word_cnt <= 16'b0;
	else if (rcv_op_end)										data_word_cnt <= 16'b0;
	else if (rcv_op & tcp_prot & (word_cnt >= 5) & (word_cnt >= tcp_head_len))	
																	data_word_cnt <= data_word_cnt + 1'b1;

//START UDP DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_op_start_r <= 1'b0;
	else if (upper_op_start_r)								upper_op_start_r <= 1'b0;
	else if (rcv_op & tcp_prot & (word_cnt == tcp_head_len) & (packet_length > (tcp_head_len * 4)))
																	upper_op_start_r <= 1'b1;
								
//STOP UDP DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_op_stop_r <= 1'b0;
	else if (upper_op_stop_r)								upper_op_stop_r <= 1'b0;
	else if (rcv_op_end & rcv_op & tcp_prot & (packet_length > (tcp_head_len * 4)))
																	upper_op_stop_r <= 1'b1;
						
//RECEIVE DATA OPERATION
always @(posedge clk or negedge rst_n)
	if (!rst_n)													upper_op_r <= 1'b0;
	else if (rcv_op & tcp_prot & (word_cnt == tcp_head_len) & (packet_length > (tcp_head_len * 4)))
																	upper_op_r <= 1'b1;
	/*else if (rcv_op & tcp_prot & upper_op_r & (word_cnt == tcp_head_len) & (packet_length > (word_cnt << 2)))		//TODO CHECK IT
																	upper_op_r <= 1'b1;																
	else 															upper_op_r <= 1'b0;*/
	else if (upper_op_stop_r)								upper_op_r <= 1'b0;	
																												
//DATA CRC
always @(posedge clk or negedge rst_n)
	if (!rst_n)													crc_dat_r <= 32'b0;
	else if (rcv_op & rcv_op_st)							crc_dat_r <= 32'b0;
	else if (rcv_op & tcp_prot & (word_cnt == 5) & (packet_length >= (tcp_head_len * 4)))
																	crc_dat_r <= crc_dat_w;
	else if (rcv_op & tcp_prot & (word_cnt > 5) & (packet_length > (word_cnt << 2)))													//TODO CHECK IT
																	crc_dat_r <= crc_dat_w;
	
assign crc_dat_w = crc_dat_r + rcv_data[31:16] + rcv_data[15:0];
assign crc_dat_ww = crc_dat_w[31:16] + crc_dat_w[15:0];
assign crc_dat_www = crc_dat_ww[31:16] + crc_dat_ww[15:0];

//CRC SUMMARY
assign crc_sum_w = crc_head_www + crc_dat_www + pseudo_crc_sum;
assign crc_sum_ww = crc_sum_w[31:16] + crc_sum_w[15:0];
assign crc_sum_www = crc_sum_ww[31:16] + crc_sum_ww[15:0];


//INOUTS
assign source_port_o		= source_port;
assign dest_port_o		= dest_port;
assign packet_length_o	= packet_length;
assign checksum_o			= checksum;
assign crc_sum_o			= crc_sum_www;

assign upper_op_st		= upper_op_start_r;
assign upper_op			= upper_op_r;
assign upper_op_end		= upper_op_stop_r;
assign upper_data			= upper_data_r;


assign seq_num_o			= seq_num;
assign ack_num_o			= ack_num;
assign tcp_flags_o		= tcp_flags;
assign tcp_head_len_o	= tcp_head_len;
assign options_o			= options_reg[95:0];
assign tcp_window_o		= tcp_window;






endmodule
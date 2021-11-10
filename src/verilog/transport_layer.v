module transport_layer
(
	input					clk
	,input				rst_n

	,input				rcv_op_st
	,input				rcv_op
	,input				rcv_op_end
	,input	[31:0]	rcv_data
	,input	[7:0]		prot_type
	,input	[15:0]	pseudo_crc_sum


	,output	[15:0]	source_port_o
	,output	[15:0]	dest_port_o
	,output	[15:0]	packet_length_o
	,output	[15:0]	checksum_o

	,output				upper_op_st
	,output				upper_op
	,output				upper_op_end
	,output	[31:0]	upper_data
	,output	[15:0]	crc_sum_o

	
);

//UDP FIELDS
reg	[15:0]	source_port;
reg	[15:0]	dest_port;
reg	[15:0]	packet_length;
reg	[15:0]	checksum;

reg	[15:0]	word_cnt;
reg	[15:0]	data_word_cnt;

reg				upper_op_start_r;
reg				upper_op_r;
reg				upper_op_stop_r;
reg	[31:0]	upper_data_r;

reg	[15:0]	crc_dat_r;

wire	[31:0]	crc_head_w;
wire	[15:0]	crc_head_ww;
wire	[31:0]	crc_dat_w;
wire	[31:0]	crc_dat_ww;
wire	[31:0]	crc_sum_w;
wire	[15:0]	crc_sum_ww;
wire				udp_prot_w;

assign udp_prot = prot_type == 8'd17;

always @(posedge clk or negedge rst_n)
	if (!rst_n) 						word_cnt <= 16'b0;
	else if (rcv_op_end)				word_cnt <= 16'b0;
	else if (rcv_op & udp_prot)	word_cnt <= word_cnt + 1'b1;

//UDP FIELDS
//-------------------------------------------------------------------------------
//VERSION NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												source_port <= 16'b0;
	else if (rcv_op_st & rcv_op & udp_prot)			source_port <= rcv_data[31:16];
	
//DESTINATION PORT
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												dest_port <= 16'b0;
	else if (rcv_op_st & rcv_op & udp_prot)			dest_port <= rcv_data[15:0];
	
//PACKET LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												packet_length <= 16'b0;
	else if (rcv_op & (word_cnt == 1) & udp_prot)	packet_length <= rcv_data[31:16];
	
//CHECKSUM
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												checksum <= 16'b0;
	else if (rcv_op & (word_cnt == 1) & udp_prot)	checksum <= rcv_data[15:0];

//CRC HEADER
assign crc_head_w = source_port + dest_port + packet_length + packet_length + checksum;
assign crc_head_ww = crc_head_w[31:16] + crc_head_w[15:0];

//UDP DATA
//-------------------------------------------------------------------------------
//RECEIVE DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_data_r <= 32'b0;
	else if (rcv_op & udp_prot & (word_cnt >= 2))	upper_data_r <= rcv_data;
	else 															upper_data_r <= 32'b0;
	
//UDP DATA WORD COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												data_word_cnt <= 16'b0;
	else if (rcv_op_end)										data_word_cnt <= 16'b0;
	else if (rcv_op & udp_prot & (word_cnt >= 2))	data_word_cnt <= data_word_cnt + 1'b1;

//START UDP DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_op_start_r <= 1'b0;
	else if (upper_op_start_r)								upper_op_start_r <= 1'b0;
	else if (rcv_op & udp_prot & (word_cnt == 2) & (packet_length >= 9))
																	upper_op_start_r <= 1'b1;
								
//STOP UDP DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 												upper_op_stop_r <= 1'b0;
	else if (upper_op_stop_r)								upper_op_stop_r <= 1'b0;
	else if (rcv_op_end & rcv_op & udp_prot & (packet_length >= 9))			
																	upper_op_stop_r <= 1'b1;
						
//RECEIVE DATA OPERATION
always @(posedge clk or negedge rst_n)
	if (!rst_n)													upper_op_r <= 1'b0;
	else if (rcv_op & udp_prot & (word_cnt == 2) & (packet_length >= 9))
																	upper_op_r <= 1'b1;
	else if (rcv_op & udp_prot & (word_cnt > 2) & (packet_length > (word_cnt << 2)))
																	upper_op_r <= 1'b1;																
	else 															upper_op_r <= 1'b0;
																												
//DATA CRC
always @(posedge clk or negedge rst_n)
	if (!rst_n)													crc_dat_r <= 16'b0;
	else if (rcv_op & rcv_op_st)							crc_dat_r <= 16'b0;
	else if (rcv_op & udp_prot & (word_cnt == 2) & (packet_length >= 9))
																	crc_dat_r <= crc_dat_ww;
	else if (rcv_op & udp_prot & (word_cnt > 2) & (packet_length > (word_cnt << 2)))
																	crc_dat_r <= crc_dat_ww;
	
assign crc_dat_w = crc_dat_r + rcv_data[31:16] + rcv_data[15:0];
assign crc_dat_ww = crc_dat_w[31:16] + crc_dat_w[15:0];

//CRC SUMMARY
assign crc_sum_w = crc_head_ww + crc_dat_ww + pseudo_crc_sum;
assign crc_sum_ww = crc_sum_w[31:16] + crc_sum_w[15:0];


//INOUTS
assign source_port_o		= source_port;
assign dest_port_o		= dest_port;
assign packet_length_o	= packet_length;
assign checksum_o			= checksum;
assign crc_sum_o			= crc_sum_ww;

assign upper_op_st		= upper_op_start_r;
assign upper_op			= upper_op_r;
assign upper_op_end		= upper_op_stop_r;
assign upper_data			= upper_data_r;










endmodule
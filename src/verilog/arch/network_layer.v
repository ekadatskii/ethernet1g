//TODO Проверка CRC, отложенный старт на доп поля IP, другие протоколы
module network_layer
(
	input					clk
	,input				rst_n

	,input				rcv_op
	,input				rcv_op_st
	,input				rcv_op_end
	,input	[31:0]	rcv_data
	,input	[47:0]	source_addr_i
	,input	[47:0]	dest_addr_i
	,input	[15:0]	prot_type_i

	,output				upper_op_st
	,output				upper_op
	,output				upper_op_end
	,output	[31:0]	upper_data

	,output	[3:0]		version_num_o
	,output	[3:0]		header_len_o
	,output	[7:0]		service_type_o
	,output	[15:0]	total_len_o
	,output	[15:0]	packet_id_o
	,output	[2:0]		flags_o
	,output	[12:0]	frgmt_offset_o
	,output	[7:0]		ttl_o
	,output	[7:0]		prot_type_o
	,output	[15:0]	checksum_o
	,output	[31:0]	source_addr_o
	,output	[31:0]	dest_addr_o
	,output	[15:0]	crc_sum_o
	,output	[15:0]	pseudo_crc_sum_o
);

//IP fields
reg	[3:0]		version_num;
reg	[3:0]		header_len;
reg	[7:0]		service_type;
reg	[15:0]	total_len;
reg	[15:0]	packet_id;
reg	[2:0]		flags;
reg	[12:0]	frgmt_offset;
reg	[7:0]		ttl;
reg	[7:0]		prot_type;
reg	[15:0]	checksum;
reg	[31:0]	source_addr;
reg	[31:0]	dest_addr;

reg	[15:0]	word_cnt;

reg				upper_op_r;
reg				upper_op_start_r;
reg				upper_op_stop_r;
reg	[31:0]	upper_data_r;

reg	[15:0]	crc_sum_r;
wire	[31:0]	crc_sum_w;
wire	[31:0]	crc_sum_ww;
wire	[31:0]	pseudo_crc_sum_w;
wire	[15:0]	pseudo_crc_sum_ww;
wire				upper_op_run_w;

//WORD COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 				word_cnt <= 16'b0;
	else if (rcv_op_end)		word_cnt <= 16'b0;
	else if (rcv_op)			word_cnt <= word_cnt + 1'b1;

//IP FIELDS
//-------------------------------------------------------------------------------
//VERSION NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									version_num <= 4'b0;
	else if (rcv_op_st & rcv_op)				version_num <= rcv_data[31:28];	
	
//HEADER LENGHT
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									header_len <= 4'b0;
	else if (rcv_op_st & rcv_op)				header_len <= rcv_data[27:24];
	
//SERVICE TYPE
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									service_type <= 8'b0;
	else if (rcv_op_st & rcv_op)				service_type <= rcv_data[23:16];
	
//TOTAL LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									total_len <= 16'b0;
	else if (rcv_op_st & rcv_op)				total_len <= rcv_data[15:0];
	
//PACKET ID
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									packet_id <= 16'b0;
	else if (rcv_op & (word_cnt == 1))		packet_id <= rcv_data[31: 16];
	
//FLAGS
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									flags <= 3'b0;
	else if (rcv_op & (word_cnt == 1))		flags <= rcv_data[15:13];
	
//FRAGMENT OFFSET
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									frgmt_offset <= 13'b0;
	else if (rcv_op & (word_cnt == 1))		frgmt_offset <= rcv_data[12:0];

//TIME TO LIVE
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									ttl <= 8'b0;
	else if (rcv_op & (word_cnt == 2))		ttl <= rcv_data[31:24];

//PROTOCOL TYPE(UPPER LEVEL)
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									prot_type <= 8'b0;
	else if (rcv_op & (word_cnt == 2))		prot_type <= rcv_data[23:16];
	
//CHECKSUM
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									checksum <= 16'b0;
	else if (rcv_op & (word_cnt == 2))		checksum <= rcv_data[15:0];

//SOURCE ADDRESS(IP)
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									source_addr <= 32'b0;
	else if (rcv_op & (word_cnt == 3))		source_addr <= rcv_data;

//DESTINATION ADDRESS(IP)
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									dest_addr <= 32'b0;
	else if (rcv_op & (word_cnt == 4))		dest_addr <= rcv_data;
	
//CRC CALCULATION
always @(posedge clk or negedge rst_n)
	if (!rst_n)												crc_sum_r <= 16'b0;
	else if (rcv_op & rcv_op_st)						crc_sum_r <= crc_sum_ww;
	else if (rcv_op & (word_cnt < header_len))	crc_sum_r <= crc_sum_ww;

assign crc_sum_w = 	(rcv_op & rcv_op_st)						? 	(rcv_data[31:16] + rcv_data[15:0]) :
							(rcv_op & (word_cnt < header_len))	? 	(crc_sum_r + rcv_data[31:16] + rcv_data[15:0]) : 32'b0;
assign crc_sum_ww = crc_sum_w[15:0] + crc_sum_w[31:16];

//PSEUDOHEADER CRC
assign pseudo_crc_sum_w = source_addr[31:16] + source_addr[15:0] + dest_addr[31:16] + dest_addr[15:0] + prot_type[7:0];
assign pseudo_crc_sum_ww = pseudo_crc_sum_w[31:16] + pseudo_crc_sum_w[15:0];

//TRANSPORT PROCESS(UPPER LEVEL)
//-------------------------------------------------------------------------------	
//START TRANSPORT LAYER PACKET
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									upper_op_start_r <= 1'b0;
	else if (upper_op_start_r)					upper_op_start_r <= 1'b0;
	else if ((word_cnt == header_len) & upper_op_run_w & rcv_op)
														upper_op_start_r <= 1'b1;
														
assign upper_op_run_w =	(prot_type_i == 16'h0800) & (prot_type == 8'd17) & (word_cnt >= 5) & (dest_addr == 32'hffffffff) &
								(crc_sum_r == 16'hffff);
										
	
//STOP TRANSPORT LAYER PACKET
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									upper_op_stop_r <= 1'b0;
	else if (upper_op_stop_r)					upper_op_stop_r <= 1'b0;
	else if (rcv_op_end & rcv_op & upper_op_run_w)				
														upper_op_stop_r <= 1'b1;
	
//RECEIVE DATA OPERATION
always @(posedge clk or negedge rst_n)
	if (!rst_n)										upper_op_r <= 1'b0;
	else if (upper_op_run_w & (word_cnt >= header_len) & rcv_op)
														upper_op_r <= 1'b1;
	else 												upper_op_r <= 1'b0;
														
//TRANSPORT LEVEL HEAD&DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n) 								upper_data_r <= 32'b0;
	else if (rcv_op & upper_op_run_w & (word_cnt >= header_len) & rcv_op)
													upper_data_r <= rcv_data;	
	else 											upper_data_r <= 32'b0;													

//INOUTS
assign version_num_o		= version_num;
assign header_len_o		= header_len;
assign service_type_o	= service_type;
assign total_len_o		= total_len;
assign packet_id_o		= packet_id;
assign flags_o				= flags;
assign frgmt_offset_o	= frgmt_offset;
assign ttl_o				= ttl;
assign prot_type_o		= prot_type;
assign checksum_o			= checksum;
assign source_addr_o		= source_addr;
assign dest_addr_o		= dest_addr;
assign crc_sum_o			= crc_sum_r;
assign pseudo_crc_sum_o = pseudo_crc_sum_ww;
	
assign upper_op_st		= upper_op_start_r;
assign upper_op			= upper_op_r;
assign upper_op_end		= upper_op_stop_r;
assign upper_data			= upper_data_r;


endmodule
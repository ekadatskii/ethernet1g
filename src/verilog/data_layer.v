module data_layer
(
	input					clk
	,input				rst_n				

	,input				Rx_mac_ra               
	,input	[31:0]	Rx_mac_data             
	,input	[1:0]		Rx_mac_BE               
	,input				Rx_mac_pa               
	,input				Rx_mac_sop              
	,input				Rx_mac_eop

	,output				upper_op_st
	,output				upper_op
	,output				upper_op_end
	,output	[31:0]	upper_data

	,output	[47:0]	source_addr_o
	,output	[47:0]	dest_addr_o
	,output	[15:0]	prot_type_o
);

reg	[47:0]	destination_r;
reg	[47:0]	source_r;
reg	[15:0]	protocol_r;

reg	[15:0]	word_cnt;

reg				upper_op_start_r;
reg				upper_op_stop_r;
reg				upper_op_stop_hold_r;
reg				upper_op_r;
reg				upper_op_hold_r;
reg	[47:0]	upper_data_r;


//WORD COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 								word_cnt <= 16'b0;
	else if (Rx_mac_eop)						word_cnt <= 16'b0;
//	else if (Rx_mac_eop & Rx_mac_pa)		word_cnt <= 16'b0;	
	else if (Rx_mac_pa)						word_cnt <= word_cnt + 1'b1;

//DESTINATION
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									destination_r <= 48'b0;
	else if ((word_cnt == 0) & Rx_mac_pa)	destination_r[47:16] <= Rx_mac_data;
	else if ((word_cnt == 1) & Rx_mac_pa)	destination_r[15: 0] <= Rx_mac_data[31:16];

//SOURCE
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									source_r <= 48'b0;
	else if ((word_cnt == 1) & Rx_mac_pa)	source_r[47:32] <= Rx_mac_data[15: 0];
	else if ((word_cnt == 2) & Rx_mac_pa)	source_r[31: 0] <= Rx_mac_data;

//PROTOCOL
always @(posedge clk or negedge rst_n)
	if (!rst_n) protocol_r <= 16'b0;
	else if ((word_cnt == 3) & Rx_mac_pa)	protocol_r <= Rx_mac_data[31:16];

//START IP PACKET
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									upper_op_start_r <= 1'b0;
	else if (upper_op_start_r)					upper_op_start_r <= 1'b0;
	else if ((word_cnt == 4) & Rx_mac_pa)	upper_op_start_r <= 1'b1;
	
//STOP IP PACKET
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									upper_op_stop_r <= 1'b0;
	else if (upper_op_stop_r)					upper_op_stop_r <= 1'b0;
	else if (upper_op_stop_hold_r)			upper_op_stop_r <= 1'b1;
	else if (Rx_mac_pa & Rx_mac_eop & !(Rx_mac_BE == 2'h0 | Rx_mac_BE == 2'h3))
														upper_op_stop_r <= 1'b1;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									upper_op_stop_hold_r <= 1'b0;
	else if (Rx_mac_pa & Rx_mac_eop & (Rx_mac_BE == 2'h0 | Rx_mac_BE == 2'h3))
														upper_op_stop_hold_r <= 1'b1;
	else 												upper_op_stop_hold_r <= 1'b0;

//RECEIVE DATA OPERATION
always @(posedge clk or negedge rst_n)
	if (!rst_n)										upper_op_r <= 1'b0;
	else if (upper_op_hold_r)					upper_op_r <= 1'b1;
	else if ((word_cnt >= 4) & Rx_mac_pa)	upper_op_r <= 1'b1;
	else 												upper_op_r <= 1'b0;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									upper_op_hold_r <= 1'b0;
	else if (Rx_mac_pa & Rx_mac_eop & (Rx_mac_BE == 2'h0 | Rx_mac_BE == 2'h3))
														upper_op_hold_r <= 1'b1;
	else 												upper_op_hold_r <= 1'b0;

//IP DATA OUT
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									upper_data_r <= 48'b0;
	else if (Rx_mac_pa & Rx_mac_BE == 1)	upper_data_r <= {upper_data_r[15:0],  Rx_mac_data[31:24], 24'b0};
	else if (Rx_mac_pa & Rx_mac_BE == 2)	upper_data_r <= {upper_data_r[15:0],  Rx_mac_data[31:16], 16'b0};
	else if (Rx_mac_pa & Rx_mac_BE == 3)	upper_data_r <= {upper_data_r[15:0],  Rx_mac_data[31:8],   8'b0};
	else if (Rx_mac_pa)							upper_data_r <= {upper_data_r[15:0],  Rx_mac_data};
	else 												upper_data_r <= {upper_data_r[15:0],  32'b0};

//INOUTS
assign source_addr_o = source_r;
assign dest_addr_o 	= destination_r;
assign prot_type_o	= protocol_r;

assign upper_op_st	= upper_op_start_r;
assign upper_op  		= upper_op_r;
assign upper_op_end	= upper_op_stop_r;
assign upper_data 	= upper_data_r[47:16];
	

endmodule
module mac_head_transmitter
(
	input				clk
	,input			rst_n
	
	//control signals
	,input					mac_start
	
	//packet parameters
	,input	[47:0]		mac_src_addr
	,input	[47:0]		mac_dst_addr
	,input	[15:0]		mac_type
	
	//status signals
	,output					mac_busy	
	
	//output data + controls
	,output	[31:0]		mac_data_out
	,output	[ 1:0]		mac_be_out
	,output					mac_data_out_rdy
	,input					mac_data_out_sel
	,input					mac_data_out_rd
);

reg				mac_work_r;
reg				mac_data_out_rdy_r;

reg	[47:0]	mac_src_addr_r;
reg	[47:0]	mac_dst_addr_r;
reg	[15:0]	mac_type_r;

reg	[3 :0]	mac_head_ptr;

wire				mac_stop;

//MAC WORK SIGNAL
always @(posedge clk or negedge rst_n)
	if (!rst_n)				mac_work_r <= 1'b0;
	else if (mac_stop)	mac_work_r <= 1'b0;
	else if (mac_start)	mac_work_r <= 1'b1;

//MAC SOURCE ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									mac_src_addr_r <= 48'b0;
	else if (mac_start & !mac_work_r)	mac_src_addr_r <= mac_src_addr;

//MAC DESTINATION ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									mac_dst_addr_r <= 48'b0;
	else if (mac_start & !mac_work_r)	mac_dst_addr_r <= mac_dst_addr;

//MAC TYPE
always @(posedge clk or negedge rst_n)
	if (!rst_n)									mac_type_r <= 16'b0;
	else if (mac_start & !mac_work_r)	mac_type_r <= mac_type;
	
//MAC HEADER POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)																	mac_head_ptr <= 4'b0;
	else if (mac_stop)														mac_head_ptr <= 4'b0;
	else if (mac_work_r & mac_data_out_sel & mac_data_out_rd)	mac_head_ptr <= mac_head_ptr + 4'd1;

//MAC FRAGMENT SEND STOP
assign mac_stop = mac_work_r & mac_data_out_sel & mac_data_out_rd & ((mac_head_ptr + 4'd1) == 4'd4);

//MAC OUT DATA READY
always @(posedge clk or negedge rst_n)
	if (!rst_n)					mac_data_out_rdy_r <= 1'b0;
	else if (mac_stop)		mac_data_out_rdy_r <= 1'b0;
	else if (mac_start)		mac_data_out_rdy_r <= 1'b1;

//Output signals
assign mac_busy 			=	mac_work_r;
assign mac_data_out_rdy =	mac_data_out_rdy_r;
assign mac_data_out 		=	(mac_head_ptr == 4'd0) ? mac_dst_addr_r[47:16]:
									(mac_head_ptr == 4'd1) ? {mac_dst_addr_r[15: 0], mac_src_addr_r[47:32]}:
									(mac_head_ptr == 4'd2) ? mac_src_addr_r[31:0]:
									(mac_head_ptr == 4'd3) ? {mac_type_r, 16'b0}:
									32'h0;

//MAC BYTE ENABLE
assign mac_be_out = 	(mac_head_ptr == 4'd0) ? 2'b00:
							(mac_head_ptr == 4'd1) ? 2'b00:
							(mac_head_ptr == 4'd2) ? 2'b00:
							(mac_head_ptr == 4'd3) ? 2'b10:
							2'b0000;


endmodule
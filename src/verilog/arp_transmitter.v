module arp_transmitter
(
	input				clk
	,input			rst_n
	
	//control signals
	,input					start
	
	//output data + controls
	,output	[31:0]		data_out
	,output	[ 1:0]		be_out
	,output					data_out_rdy
	,input					data_out_rd
	,output					sop
	,output					eop
	
	//
	,input	[47:0]		mac_src_addr
	,input	[47:0]		mac_dst_addr
	,input	[15:0]		mac_type	
	
	//input parameters
	,input	[15:0]		hardw_type
	,input	[15:0]		prot_type
	,input	[ 7:0]		hardw_length
	,input	[ 7:0]		prot_length
	,input	[15:0]		operation_code
	
	,input	[47: 0]		sender_haddr
	,input	[31: 0]		sender_paddr
	,input	[47: 0]		target_haddr
	,input	[31: 0]		target_paddr	
);

reg	[47:0]	mac_src_addr_r;
reg	[47:0]	mac_dst_addr_r;
reg	[15:0]	mac_type_r;

reg	[15:0]	hardw_type_r;
reg	[15:0]	prot_type_r;
reg	[ 7:0]	hardw_length_r;
reg	[ 7:0]	prot_length_r;
reg	[15:0]	operation_code_r;	
	
reg	[47: 0]	sender_haddr_r;
reg	[31: 0]	sender_paddr_r;
reg	[47: 0]	target_haddr_r;
reg	[31: 0]	target_paddr_r;	

//--------------------------------

reg				work_r;
reg				data_out_rdy_r;
wire				stop;
reg	[15:0]	head_ptr;
reg				head_ph;

//--------------------------------

//WORK SIGNAL
always @(posedge clk or negedge rst_n)
	if (!rst_n)				work_r <= 1'b0;
	else if (stop)			work_r <= 1'b0;
	else if (start)		work_r <= 1'b1;
	
//HEADER POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)				head_ph <= 1'b0;
	else if (start)		head_ph <= 1'b1;
	else if ((head_ptr == 16'd10) & data_out_rd)
								head_ph <= 1'b0;
	
//HEADER POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)													head_ptr <= 16'b0;
	else if (stop)												head_ptr <= 16'b0;
	else if (work_r & data_out_rd & head_ph)			head_ptr <= head_ptr + 4'd1;
	
//START OPERATION
assign sop = work_r & (head_ptr == 16'd0);

//END OPERATION
assign eop = stop;

assign data_out	 		=	(head_ptr == 16'd0)  ? mac_dst_addr_r[47:16]:
									(head_ptr == 16'd1)  ? {mac_dst_addr_r[15: 0], mac_src_addr_r[47:32]}:
									(head_ptr == 16'd2)  ? mac_src_addr_r[31:0]:
									(head_ptr == 16'd3)  ? {mac_type_r, hardw_type_r}:
									(head_ptr == 16'd4)  ? {prot_type_r, hardw_length_r, prot_length_r}:
									(head_ptr == 16'd5)  ? {operation_code_r, sender_haddr_r[47:32]}:
									(head_ptr == 16'd6)  ? {sender_haddr_r[31:0]}:									
									(head_ptr == 16'd7)  ? {sender_paddr_r}:
									(head_ptr == 16'd8)  ? {target_haddr_r[47:16]}:
									(head_ptr == 16'd9)  ? {target_haddr_r[15:0], target_paddr_r[31:16]}:
									(head_ptr == 16'd10) ? {target_paddr_r[15:0], {16{1'b0}}}:
									32'h0;									
									
assign be_out		 		=	(head_ptr == 4'd0)  ? 2'b00:
									(head_ptr == 4'd1)  ? 2'b00:
									(head_ptr == 4'd2)  ? 2'b00:
									(head_ptr == 4'd3)  ? 2'b00:
									(head_ptr == 4'd4)  ? 2'b00:
									(head_ptr == 4'd5)  ? 2'b00:
									(head_ptr == 4'd6)  ? 2'b00:
									(head_ptr == 4'd7)  ? 2'b00:
									(head_ptr == 4'd8)  ? 2'b00:
									(head_ptr == 4'd9)  ? 2'b00:
									(head_ptr == 4'd10) ? 2'b10:									
									2'b00;									

always @(posedge clk or negedge rst_n)
	if (!rst_n)			data_out_rdy_r <= 1'b0;
	else if (stop)		data_out_rdy_r <= 1'b0;
	else if (start)	data_out_rdy_r <= 1'b1;				

assign data_out_rdy = data_out_rdy_r;

assign stop = work_r & data_out_rd & (head_ptr == 16'd10);
//-------------------------------------------------------------------------------------------------------------	

//MAC SOURCE ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								mac_src_addr_r <= 48'b0;
	else if (start & !work_r)			mac_src_addr_r <= mac_src_addr;

//MAC DESTINATION ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								mac_dst_addr_r <= 48'b0;
	else if (start & !work_r)			mac_dst_addr_r <= mac_dst_addr;

//MAC TYPE
always @(posedge clk or negedge rst_n)
	if (!rst_n)								mac_type_r <= 16'b0;
	else if (start & !work_r)			mac_type_r <= mac_type;

//-------------------------------------------------------------------------------------------------------------
//HARDWARE TYPE
always @(posedge clk or negedge rst_n)
	if (!rst_n)								hardw_type_r <= 16'b0;
	else if (start & !work_r)			hardw_type_r <= hardw_type;
	
//PROTOCOL TYPE	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								prot_type_r <= 16'b0;
	else if (start & !work_r)			prot_type_r <= prot_type;

//HARDWARE LENGTH	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								hardw_length_r <= 8'b0;
	else if (start & !work_r)			hardw_length_r <= hardw_length;
	
//PROTOCOL LENGTH	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								prot_length_r <= 8'b0;
	else if (start & !work_r)			prot_length_r <= prot_length;
	
//OPERATION CODE	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								operation_code_r <= 16'b0;
	else if (start & !work_r)			operation_code_r <= operation_code;
	
//SENDER HARDWARE(MAC) ADDRESS	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								sender_haddr_r <= 48'b0;
	else if (start & !work_r)			sender_haddr_r <= sender_haddr;
	
//SENDER PROTOCOL(IP) ADDRESS	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								sender_paddr_r <= 32'b0;
	else if (start & !work_r)			sender_paddr_r <= sender_paddr;

//TARGET HARDWARE(MAC) ADDRESS	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								target_haddr_r <= 48'b0;
	else if (start & !work_r)			target_haddr_r <= target_haddr;
	
//SENDER PROTOCOL(IP) ADDRESS	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								target_paddr_r <= 32'b0;
	else if (start & !work_r)			target_paddr_r <= target_paddr;


endmodule

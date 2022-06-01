module arp_receiver
(
	input					clk
	,input				rst_n
	,input	[31:0]	dev_ip_addr_i

	,input				rcv_op_i
	,input				rcv_op_st_i
	,input				rcv_op_end_i
	,input	[31:0]	rcv_data_i
	,input	[47:0]	source_addr_i
	,input	[47:0]	dest_addr_i
	,input	[15:0]	prot_type_i
	
	,output	[47: 0]	sender_haddr_o
	,output	[31: 0]	sender_paddr_o
	,output	[47: 0]	target_haddr_o
	,output	[31: 0]	target_paddr_o
	
	,output				op_cmplt_o
);

//ARP fields
reg	[15:0]	hardw_type;
reg	[15:0]	prot_type;
reg	[ 7:0]	hardw_length;
reg	[ 7:0]	prot_length;
reg	[15:0]	operation_code;
reg	[47:0]	sender_hardw_addr;
reg	[31:0]	sender_prot_addr;
reg	[47:0]	target_hardw_addr;
reg	[31:0]	target_prot_addr;

reg	[15:0]	word_cnt;
reg				op_cmplt;

wire				rcv_op;
wire				rcv_op_st;
wire				rcv_op_end;
wire	[31:0]	rcv_data;
wire				mac_check;
wire				prot_check;

//DESTINATION MAC ADDRESS CHECK
assign mac_check	= 1'b1;//dest_addr_i == 48'hFFFF_FFFF_FFFF;

//ETHERNET PROTOCOL CHECK
assign prot_check	= prot_type_i == 16'h0806;	//ARP

//INPUT CONTROL SIGNALS AFTER MAC ADDRESS FILTER
assign rcv_op		= rcv_op_i 		& mac_check & prot_check;
assign rcv_op_st	= rcv_op_st_i	& mac_check & prot_check;
assign rcv_op_end	= rcv_op_end_i	& mac_check & prot_check;
assign rcv_data	= (mac_check & prot_check)	? rcv_data_i : {32{1'b0}};

//WORD COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n) 				word_cnt <= 16'b0;
	else if (rcv_op_end)		word_cnt <= 16'b0;
	else if (rcv_op)			word_cnt <= word_cnt + 1'b1;
	
//ARP FIELDS
//-------------------------------------------------------------------------------
//HARDWARE TYPE
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									hardw_type <= 16'b0;
	else if (rcv_op_st & rcv_op)				hardw_type <= rcv_data[31:16];

//PROTOCOL TYPE
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									prot_type <= 16'b0;
	else if (rcv_op_st & rcv_op)				prot_type <= rcv_data[15:0];
		
//HARDWARE LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									hardw_length <= 8'b0;
	else if (rcv_op & (word_cnt == 1))		hardw_length <= rcv_data[31:24];
	
//PROTOCOL LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									prot_length <= 8'b0;
	else if (rcv_op & (word_cnt == 1))		prot_length <= rcv_data[23:16];
	
//OPERATION CODE
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									operation_code <= 16'b0;
	else if (rcv_op & (word_cnt == 1))		operation_code <= rcv_data[15:0];
	
//SENDER HARDWARE(MAC) ADDRESS
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									sender_hardw_addr <= 48'b0;
	else if (rcv_op & (word_cnt == 2))		sender_hardw_addr[47:16] <= rcv_data[31 :0];
	else if (rcv_op & (word_cnt == 3))		sender_hardw_addr[15: 0] <= rcv_data[31:16];
	
//SENDER PROTOCOL(IP) ADDRESS
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									sender_prot_addr <= 32'b0;
	else if (rcv_op & (word_cnt == 3))		sender_prot_addr[31:16] <= rcv_data[15: 0];
	else if (rcv_op & (word_cnt == 4))		sender_prot_addr[15: 0] <= rcv_data[31:16];
	
//TARGET HARDWARE(MAC) ADDRESS
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									target_hardw_addr <= 48'b0;
	else if (rcv_op & (word_cnt == 4))		target_hardw_addr[47:32] <= rcv_data[15: 0];
	else if (rcv_op & (word_cnt == 5))		target_hardw_addr[31: 0] <= rcv_data[31: 0];
	
//SENDER PROTOCOL(IP) ADDRESS
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									target_prot_addr <= 32'b0;
	else if (rcv_op & (word_cnt == 6))		target_prot_addr <= rcv_data[31:0];
	

//OPERATION COMPLETE
always @(posedge clk or negedge rst_n)
	if (!rst_n) 									op_cmplt <= 1'b0;
	else if (op_cmplt)							op_cmplt <= 1'b0;	
	else if (rcv_op & (word_cnt == 6))		op_cmplt <= 1'b1;

//INOUTS
assign sender_haddr_o	= sender_hardw_addr;
assign sender_paddr_o	= sender_prot_addr;
assign target_haddr_o	= target_hardw_addr;
assign target_paddr_o	= target_prot_addr;
assign op_cmplt_o			= op_cmplt	& (hardw_type == 1)/*ETHERNET*/ 
												& (prot_type == 16'h0800)/*IPv4*/
												& (operation_code == 1)/*REQUEST*/
												& (target_prot_addr == dev_ip_addr_i)/*IP ADDRESS CHECK*/;


endmodule
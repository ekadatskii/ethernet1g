module udp_full_transmitter
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
	,input	[31:0]		data_in
	,output					data_in_rd
	,output					sop
	,output					eop
	
	
	//packet parameters
	,input	[47:0]		mac_src_addr
	,input	[47:0]		mac_dst_addr
	,input	[15:0]		mac_type
	
	/*
	//status signals
	,output					mac_busy	
	
	//output data + controls
	,output	[31:0]		mac_data_out
	,output	[ 1:0]		mac_be_out
	,output					mac_data_out_rdy
	,input					mac_data_out_sel
	,input					mac_data_out_rd
	*/
	//---------------------------------------------------------------------
	//control signals
	
	//packet parameters
	,input	[ 3:0]		ip_version
	,input	[ 3:0]		ip_head_len
	,input	[ 7:0]		ip_dsf
	,input	[15:0]		ip_total_len
	,input	[15:0]		ip_id
	,input	[ 2:0]		ip_flag
	,input	[13:0]		ip_frag_offset
	,input	[ 7:0]		ip_ttl
	,input	[ 7:0]		ip_prot
	,input	[15:0]		ip_head_chksum		//TODO
	,input	[31:0]		ip_src_addr
	,input	[31:0]		ip_dst_addr
	,input	[31:0]		ip_options
	
	//status signals
	/*
	,output					ip_busy	
	
	//output data + controls
	,output	[31:0]		ip_data_out
	,output	[ 1:0]		ip_be_out
	,output					ip_data_out_rdy
	,input					ip_data_out_sel
	,input					ip_data_out_rd
	*/
	//---------------------------------------------------------------------	
	//control signals
	
	//packet parameters
	,input	[15:0]		udp_src_port
	,input	[15:0]		udp_dst_port
	,input	[15:0]		udp_data_length
//	,input	[15:0]		udp_chksum		TODO
	
	//input data
/*	
	,input	[31:0]		udp_data_in
	,output					udp_data_in_rd
*/	
	/*	
	//status signals
	,output					udp_busy
	
	//output data + controls
	,output	[31:0]		udp_data_out
	,output	[ 1:0]		udp_be_out
	,output					udp_data_out_rdy
	,input					udp_data_out_sel
	,input					udp_data_out_rd
	*/
);


//--------------------------------
//reg				mac_data_out_rdy_r;

reg	[47:0]	mac_src_addr_r;
reg	[47:0]	mac_dst_addr_r;
reg	[15:0]	mac_type_r;

//reg	[3 :0]	mac_head_ptr;

//wire				mac_stop;
//--------------------------------
//reg				ip_data_out_rdy_r;

reg	[ 3:0]	ip_version_r;
reg	[ 3:0]	ip_head_len_r;
reg	[ 7:0]	ip_dsf_r;
reg	[15:0]	ip_total_len_r;
reg	[15:0]	ip_id_r;
reg	[ 2:0]	ip_flag_r;
reg	[13:0]	ip_frag_offset_r;
reg	[ 7:0]	ip_ttl_r;
reg	[ 7:0]	ip_prot_r;
reg	[15:0]	ip_head_chksum_r;
reg	[31:0]	ip_src_addr_r;
reg	[31:0]	ip_dst_addr_r;
reg	[31:0]	ip_options_r;

//reg	[3 :0]	ip_head_ptr;

//wire				ip_stop;
//--------------------------------
//reg				udp_data_out_rdy_r;
//reg				udp_data_rcv_ph;
//reg				udp_data_snd_ph;

reg	[15:0]	udp_src_port_r;	
reg	[15:0]	udp_dst_port_r;
reg	[15:0]	udp_length_r;
reg	[15:0]	udp_data_length_r;
reg	[15:0]	udp_chksum_r;
//reg	[31:0]	udp_data_r;

//reg	[16:0]	udp_data_ptr;

wire				udp_stop;

//--------------------------------

reg				work_r;
reg				data_out_rdy_r;
wire				stop;
//wire				rcv_stop;
//wire				snd_stop;

reg	[15:0]	head_ptr;
reg	[15:0]	data_out_ptr;
reg	[15:0]	data_in_ptr;
reg	[63:0]	data_r;
reg				head_ph;
//reg				data_rcv_ph;
//reg				data_snd_ph;

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
									(head_ptr == 16'd3)  ? {mac_type_r, ip_version_r, ip_head_len_r, ip_dsf_r}:
									(head_ptr == 16'd4)  ? {ip_total_len_r, ip_id_r}:
									(head_ptr == 16'd5)  ? {ip_flag_r, ip_frag_offset, ip_ttl_r, ip_prot_r}:
									(head_ptr == 16'd6)  ? {ip_head_chksum_r, ip_src_addr_r[31:16]}:
									(head_ptr == 16'd7)  ? {ip_src_addr_r[15:0], ip_dst_addr_r[31:16]}:
									(head_ptr == 16'd8)  ? {ip_dst_addr_r[15:0], udp_src_port_r}:
									(head_ptr == 16'd9)  ? {udp_dst_port_r[15:0], udp_length_r}:
									(head_ptr == 16'd10) ? {udp_chksum_r[15:0], data_r[63:48]}:
									(head_ptr == 16'd11) ? {data_r[63:32]}:
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
									((head_ptr == 4'd10) & (udp_data_length_r == 16'd0)) ? 2'b10:
									((head_ptr == 4'd10) & (udp_data_length_r == 16'd1)) ? 2'b11:
									(head_ptr == 4'd10) ? 2'b00:
									((head_ptr == 4'd11) & (data_out_ptr + 4'd1 == udp_data_length_r)) ? 2'b01:
									((head_ptr == 4'd11) & (data_out_ptr + 4'd2 == udp_data_length_r)) ? 2'b10:
									((head_ptr == 4'd11) & (data_out_ptr + 4'd3 == udp_data_length_r)) ? 2'b11:
									(head_ptr == 4'd11) ? 2'b00:
									2'b00;	
									
//DATA OUT POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)															data_out_ptr <= 16'b0;
	else if (stop)														data_out_ptr <= 16'b0;
	else if (work_r & data_out_rd & (head_ptr == 16'd10))	data_out_ptr <= data_out_ptr + 4'd2;
	else if (work_r & data_out_rd & (head_ptr >= 16'd11))	data_out_ptr <= data_out_ptr + 4'd4;

always @(posedge clk or negedge rst_n)
	if (!rst_n)			data_out_rdy_r <= 1'b0;
	else if (stop)		data_out_rdy_r <= 1'b0;
	else if (start)	data_out_rdy_r <= 1'b1;				

assign data_out_rdy = data_out_rdy_r;

//UDP DATA REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)																			data_r <= 64'b0;
	else if (stop)																		data_r <= 64'b0;
	else if ((head_ptr == 16'd8)  & data_out_rd/*TODO IF NO DATA*/)	data_r[63:32] <= data_in;
	else if ((head_ptr == 16'd9)  & data_out_rd/*TODO IF NO DATA*/)	data_r[31: 0] <= data_in;
	else if ((head_ptr == 16'd10) & data_out_rd/*TODO IF NO DATA*/)	data_r[63:16] <= data_r[47:0];
	else if ((head_ptr == 16'd11) & data_out_rd/*TODO IF NO DATA*/)	data_r[63:16] <= {data_r[31:16], data_in};
	
assign stop = work_r & data_out_rd & (((head_ptr == 16'd10) & (udp_data_length_r <= 16'd2)) | ((head_ptr >= 16'd11) & (data_out_ptr + 4'd4 >= udp_data_length_r)));

//DATA IN POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)							data_in_ptr <= 16'b0;
	else if (stop)						data_in_ptr <= 16'b0;
	else if (work_r & data_in_rd)	data_in_ptr <= data_in_ptr + 4'd4;


assign data_in_rd = ((head_ptr == 16'd8) | (head_ptr == 16'd9) | (head_ptr == 16'd11)) & (data_in_ptr < udp_data_length_r) & data_out_rd;
	
//-------------------------------------------------------------------------------------------------------------	

//MAC SOURCE ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									mac_src_addr_r <= 48'b0;
	else if (start & !work_r)				mac_src_addr_r <= mac_src_addr;

//MAC DESTINATION ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									mac_dst_addr_r <= 48'b0;
	else if (start & !work_r)				mac_dst_addr_r <= mac_dst_addr;

//MAC TYPE
always @(posedge clk or negedge rst_n)
	if (!rst_n)									mac_type_r <= 16'b0;
	else if (start & !work_r)				mac_type_r <= mac_type;
	
//-------------------------------------------------------------------------------------------------------------

//IP VERSION REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_version_r <= 4'b0;
	else if (start & !work_r)			ip_version_r <= ip_version;
	
//IP HEADER LENGTH REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_head_len_r <= 4'b0;
	else if (start & !work_r)			ip_head_len_r <= ip_head_len;
	
//IP DIFFERENTIATED SERVICE FIELD REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_dsf_r <= 8'b0;
	else if (start & !work_r)			ip_dsf_r <= ip_dsf;
	
//IP TOTAL LENGTH REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_total_len_r <= 16'b0;
	else if (start & !work_r)			ip_total_len_r <= ip_total_len;
	
//IP IDENTIFICATION LENGTH REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_id_r <= 16'b0;
	else if (start & !work_r)			ip_id_r <= ip_id;
	
//IP FLAG REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_flag_r <= 3'b0;
	else if (start & !work_r)			ip_flag_r <= ip_flag;
	
//IP FRAGMENT OFFSET REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_frag_offset_r <= 13'b0;
	else if (start & !work_r)			ip_frag_offset_r <= ip_frag_offset;
	
//IP TIME TO LIVE REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_ttl_r <= 8'b0;
	else if (start & !work_r)			ip_ttl_r <= ip_ttl;
	
//IP PROTOCOL REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_prot_r <= 8'b0;
	else if (start & !work_r)			ip_prot_r <= ip_prot;
	
//IP HEADER CHECKSUM REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_head_chksum_r <= 16'b0;
	else if (start & !work_r)			ip_head_chksum_r <= ip_head_chksum;		//TODO
	
//IP SOURCE ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_src_addr_r <= 32'b0;
	else if (start & !work_r)			ip_src_addr_r <= ip_src_addr;
	
//IP DESTINATION ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_dst_addr_r <= 32'b0;
	else if (start & !work_r)			ip_dst_addr_r <= ip_dst_addr;
	
//IP OPTIONS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_options_r <= 32'b0;
	else if (start & !work_r)			ip_options_r <= ip_options;
	
//-------------------------------------------------------------------------------------------------------------

//UDP SOURCE REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									udp_src_port_r <= 16'b0;
	else if (start & !work_r)				udp_src_port_r <= udp_src_port;
	
//UDP DESTINATION REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									udp_dst_port_r <= 16'b0;
	else if (start & !work_r)				udp_dst_port_r <= udp_dst_port;

//UDP LENGTH REGISTER(data length + udp packet data length(8 bytes))
always @(posedge clk or negedge rst_n)
	if (!rst_n)									udp_length_r <= 16'b0;
	else if (start & !work_r)				udp_length_r <= udp_data_length + 4'd8;
	
//UDP DATA LENGTH REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									udp_data_length_r <= 16'b0;
	else if (start & !work_r)				udp_data_length_r <= udp_data_length;
	
	
//UDP CHECKSUM
always @(posedge clk or negedge rst_n)			//TODO
	if (!rst_n)	udp_chksum_r <= 16'b0;

/*

//UDP DATA POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)																	udp_data_ptr <= 17'b0;
	else if (udp_stop)														udp_data_ptr <= 17'b0;
	else if (work_r & udp_data_out_sel & udp_data_out_rd)			udp_data_ptr <= udp_data_ptr + 4'd4;

//UDP FRAGMENT SEND STOP
assign udp_stop = work_r & udp_data_out_sel & udp_data_out_rd & ((udp_data_ptr + 4'd4) >= udp_length_r);

//UDP OUT DATA READY
always @(posedge clk or negedge rst_n)
	if (!rst_n)				udp_data_out_rdy_r <= 1'b0;
	else if (udp_stop)	udp_data_out_rdy_r <= 1'b0;
	else if (start)	udp_data_out_rdy_r <= 1'b1;
	
//UDP DATA RECEIVE PHASE
always @(posedge clk or negedge rst_n)
	if (!rst_n)																	udp_data_rcv_ph <= 1'b0;
	else if (udp_stop)														udp_data_rcv_ph <= 1'b0;
	else if (work_r & udp_data_out_sel & udp_data_out_rd)			udp_data_rcv_ph <= 1'b1;

//UDP DATA REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)																			udp_data_r <= 32'b0;
	else if (udp_stop)																udp_data_r <= 32'b0;
	else if (udp_data_rcv_ph & udp_data_out_sel & udp_data_out_rd)		udp_data_r <= udp_data_in;


//UDP DATA SEND PHASE
always @(posedge clk or negedge rst_n)
	if (!rst_n)																							udp_data_snd_ph <= 1'b0;
	else if (udp_stop)																				udp_data_snd_ph <= 1'b0;
	else if (work_r & udp_data_rcv_ph & udp_data_out_sel & udp_data_out_rd)			udp_data_snd_ph <= 1'b1;



//Output signals
assign udp_busy = 			work_r;
assign udp_data_out_rdy =	udp_data_out_rdy_r;
assign udp_data_out =		(udp_data_snd_ph) 							? udp_data_r :
									(udp_data_rcv_ph & !udp_data_snd_ph)	? {udp_length_r, udp_chksum_r} :
									(work_r & !udp_data_rcv_ph)			? {udp_src_port_r, udp_dst_port_r} : 32'h0;

//UDP BYTE ENABLE									
assign udp_be_out = 			(udp_data_snd_ph & ((udp_data_ptr + 3'd1) == udp_length_r)) ? 2'b01 :
									(udp_data_snd_ph & ((udp_data_ptr + 3'd2) == udp_length_r)) ? 2'b10 :
									(udp_data_snd_ph & ((udp_data_ptr + 3'd3) == udp_length_r)) ? 2'b11 :
									(udp_data_snd_ph)	? 2'b00 :
									(udp_data_rcv_ph & !udp_data_snd_ph)	? 2'b00 :
									(work_r & !udp_data_rcv_ph)			? 2'b00 : 
									2'b00;

//UDP INPUT DATA READ
assign udp_data_in_rd = udp_data_rcv_ph & udp_data_out_sel & udp_data_out_rd;
*/






endmodule
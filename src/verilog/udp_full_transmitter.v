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
//	,input	[15:0]		ip_head_chksum		//TODO
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
	,input	[15:0]		udp_data_chksum
	
	
	,input	[31:0]		tcp_seq_num
	,input	[31:0]		tcp_ack_num
	,input	[ 3:0]		tcp_head_len
	,input	[ 5:0]		tcp_flags
	,input	[15:0]		tcp_window
	,input	[15:0]		tcp_urgent_ptr
	,input	[95:0]		tcp_options
	
	,output					work_o
	
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
	
	,output reg	[15:0]	crc_test1
	,output reg	[15:0]	crc_test2
	,output reg	[31:0]	crc_test3
	,output reg	[31:0]	crc_test4
	,output reg	[31:0]	crc_test5
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

wire	[31:0]	ip_head_chksum_w;
wire	[31:0]	ip_head_chksum_ww;
wire	[15:0]	ip_head_chksum_www;

wire	[31:0]	pseudo_crc_sum_w;
wire	[31:0]	pseudo_crc_sum_ww;
wire	[15:0]	pseudo_crc_sum_www;


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

reg	[31:0]		tcp_seq_num_r;
reg	[31:0]		tcp_ack_num_r;
reg	[ 3:0]		tcp_head_len_r;
reg	[ 5:0]		tcp_flags_r;
reg	[15:0]		tcp_window_r;
reg	[15:0]		tcp_urgent_ptr_r;
reg	[95:0]		tcp_options_r;

wire				udp_stop;

wire	[31:0]	udp_head_crc_sum_w;
wire	[31:0]	udp_head_crc_sum_ww;
wire	[15:0]	udp_head_crc_sum_www;

wire	[31:0]	udp_full_crc_sum_w;
wire	[31:0]	udp_full_crc_sum_ww;
wire	[15:0]	udp_full_crc_sum_www;

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
	else if ((head_ptr == (16'd8 + tcp_head_len_r)) & data_out_rd)
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
									(head_ptr == 16'd9)  ? {udp_dst_port_r[15:0], tcp_seq_num[31:16]}:
									(head_ptr == 16'd10) ? {tcp_seq_num[15:0], tcp_ack_num[31:16]}:
									(head_ptr == 16'd11) ? {tcp_ack_num[15:0], tcp_head_len, 6'b0 ,tcp_flags}:
									(head_ptr == 16'd12) ? {tcp_window, udp_chksum_r}:								
									((head_ptr == 16'd13) & (tcp_head_len_r >= 4'd6)) ? {tcp_urgent_ptr, tcp_options[95:80]}:
									((head_ptr == 16'd13) & (tcp_head_len_r == 4'd5)) ? {tcp_urgent_ptr, data_r[63:48]}:
									((head_ptr == 16'd14) & (tcp_head_len_r >= 4'd7)) ? {tcp_options[79:48]}:
									((head_ptr == 16'd14) & (tcp_head_len_r == 4'd6)) ? {tcp_options[79:64], data_r[63:48]}:
									((head_ptr == 16'd15) & (tcp_head_len_r >= 4'd8)) ? {tcp_options[47:16]}:
									((head_ptr == 16'd15) & (tcp_head_len_r == 4'd7)) ? {tcp_options[47:32], data_r[63:48]}:
									((head_ptr == 16'd16) & (tcp_head_len_r == 4'd8)) ? {tcp_options[15:0], data_r[63:48]}:
									(head_ptr == (16'd8 + 16'd1 + tcp_head_len_r)) ? {data_r[63:32]}:
									32'h0;									
									
assign be_out		 		=	(head_ptr <= (16'd8  - 16'd1 + tcp_head_len_r))  ? 2'b00:									
									((head_ptr == (16'd8 + tcp_head_len_r)) & (udp_data_length_r == 16'd0)) ? 2'b10:
									((head_ptr == (16'd8 + tcp_head_len_r)) & (udp_data_length_r == 16'd1)) ? 2'b11:
									(head_ptr  == (16'd8 + tcp_head_len_r)) ? 2'b00:
									((head_ptr == (16'd8 + 16'd1 + tcp_head_len_r)) & (data_out_ptr + 4'd1 == udp_data_length_r)) ? 2'b01:
									((head_ptr == (16'd8 + 16'd1 + tcp_head_len_r)) & (data_out_ptr + 4'd2 == udp_data_length_r)) ? 2'b10:
									((head_ptr == (16'd8 + 16'd1 + tcp_head_len_r)) & (data_out_ptr + 4'd3 == udp_data_length_r)) ? 2'b11:
									(head_ptr  == (16'd8 + 16'd1 + tcp_head_len_r)) ? 2'b00:
									2'b00;	
									
//DATA OUT POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)															data_out_ptr <= 16'b0;
	else if (stop)														data_out_ptr <= 16'b0;
	else if (work_r & data_out_rd & (head_ptr == (16'd8 + tcp_head_len_r)))	
																			data_out_ptr <= data_out_ptr + 4'd2;
	else if (work_r & data_out_rd & (head_ptr == (16'd8 + 16'd1 + tcp_head_len_r)))	
																			data_out_ptr <= data_out_ptr + 4'd4;

always @(posedge clk or negedge rst_n)
	if (!rst_n)			data_out_rdy_r <= 1'b0;
	else if (stop)		data_out_rdy_r <= 1'b0;
	else if (start)	data_out_rdy_r <= 1'b1;				

assign data_out_rdy = data_out_rdy_r;

//UDP DATA REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)													data_r <= 64'b0;
	else if (stop)												data_r <= 64'b0;
	else if ((head_ptr == 16'd10) & data_out_rd)		data_r[63:32] <= data_in;
	else if ((head_ptr == 16'd11) & data_out_rd)		data_r[31: 0] <= data_in;
	else if ((head_ptr == (16'd8 + tcp_head_len_r)) & data_out_rd )			data_r[63:16] <= data_r[47:0];
	else if ((head_ptr == (16'd8 + 16'd1 + tcp_head_len_r)) & data_out_rd )	data_r[63:16] <= {data_r[31:16], data_in};

assign stop = work_r & data_out_rd & (((head_ptr == (16'd8 + tcp_head_len_r)) & (udp_data_length_r <= 16'd2)) | ((head_ptr >= (16'd8 + 16'd1 + tcp_head_len_r)) & (data_out_ptr + 4'd4 >= udp_data_length_r)));

//DATA IN POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)							data_in_ptr <= 16'b0;
	else if (stop)						data_in_ptr <= 16'b0;
	else if (work_r & data_in_rd)	data_in_ptr <= data_in_ptr + 4'd4;


assign data_in_rd = ((head_ptr == 16'd10) | (head_ptr == 16'd11) | (head_ptr == (16'd8 + 16'd1 + tcp_head_len_r))) & (data_in_ptr < udp_data_length_r) & data_out_rd;
	
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
	else if (head_ptr == 16'd1)		ip_head_chksum_r <= ~ip_head_chksum_www;
	
assign ip_head_chksum_w		= {ip_version_r, ip_head_len_r, ip_dsf_r} + ip_total_len_r + ip_id_r + {ip_flag_r, ip_frag_offset_r} + {ip_ttl_r, ip_prot_r} + ip_src_addr_r[31:16] + ip_src_addr_r[15:0] + ip_dst_addr_r[31:16] + ip_dst_addr_r[15:0];
assign ip_head_chksum_ww	= ip_head_chksum_w[31:16]+ ip_head_chksum_w[15:0];
assign ip_head_chksum_www	= ip_head_chksum_ww[31:16]+ ip_head_chksum_ww[15:0];
	
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

assign pseudo_crc_sum_w = ip_src_addr[31:16] + ip_src_addr[15:0] + ip_dst_addr[31:16] + ip_dst_addr[15:0] + ip_prot[7:0] + (udp_data_length + tcp_head_len * 4'd4);
assign pseudo_crc_sum_ww = pseudo_crc_sum_w[31:16] + pseudo_crc_sum_w[15:0];
assign pseudo_crc_sum_www = pseudo_crc_sum_ww[31:16] + pseudo_crc_sum_ww[15:0];
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								crc_test1 <= 16'b0;
	else 										crc_test1 <= pseudo_crc_sum_ww;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								crc_test2 <= 32'b0;
	else 										crc_test2 <= udp_src_port[15:0] + udp_dst_port[15:0] + tcp_seq_num[31:16] + tcp_seq_num[15:0] + tcp_ack_num[31:16] + tcp_ack_num[15:0];
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								crc_test3 <= 32'b0;
	else 										crc_test3 <= {tcp_head_len, 6'b0, tcp_flags} + tcp_window + tcp_urgent_ptr;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								crc_test4 <= 16'b0;
	else 										crc_test4 <= udp_full_crc_sum_w;//udp_head_crc_sum_ww;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)								crc_test5 <= 32'b0;
	else 										crc_test5 <= udp_full_crc_sum_www;/*((tcp_head_len >= 4'd8) ? tcp_options[95:80] : 16'h0) 
									+ ((tcp_head_len >= 4'd8) ? tcp_options[79:64] : 16'h0)
									+ ((tcp_head_len >= 4'd7) ? tcp_options[63:48] : 16'h0)
									+ ((tcp_head_len >= 4'd7) ? tcp_options[47:32] : 16'h0)
									+ ((tcp_head_len >= 4'd6) ? tcp_options[31:16] : 16'h0)
									+ ((tcp_head_len >= 4'd6) ? tcp_options[15: 0] : 16'h0);*/
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
	
//TCP SEQUENCE NUMBER REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_seq_num_r <= 32'b0;
	else if (start & !work_r)				tcp_seq_num_r <= tcp_seq_num;
	
//TCP ACKNOWLEDGE NUMBER REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_ack_num_r <= 32'b0;
	else if (start & !work_r)				tcp_ack_num_r <= tcp_ack_num;
	
//TCP HEADER LENGTH NUMBER REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_head_len_r <= 4'b0;
	else if (start & !work_r)				tcp_head_len_r <= tcp_head_len;
	
//TCP FLAGS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_flags_r <= 6'b0;
	else if (start & !work_r)				tcp_flags_r <= tcp_flags;
	
//TCP WINDOWS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_window_r <= 16'b0;
	else if (start & !work_r)				tcp_window_r <= tcp_window;
	
//TCP URGENT POUNTER REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_urgent_ptr_r <= 16'b0;
	else if (start & !work_r)				tcp_urgent_ptr_r <= tcp_urgent_ptr;
	
//TCP OPTIONS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_options_r <= 96'b0;
	else if (start & !work_r & (tcp_head_len == 4'd8))
													tcp_options_r <= tcp_options;
	else if (start & !work_r & (tcp_head_len == 4'd7))
													tcp_options_r <= {tcp_options[95:32], 32'b0};											
	else if (start & !work_r & (tcp_head_len == 4'd6))
													tcp_options_r <= {tcp_options[95:64], 64'b0};	
	else if (start & !work_r & (tcp_head_len == 4'd5))
													tcp_options_r <= 96'b0;

//UDP CHECKSUM
always @(posedge clk or negedge rst_n)
	if (!rst_n)								udp_chksum_r <= 16'b0;
	//write after initialization
	else if (head_ptr == 16'd1) 		udp_chksum_r <= ~udp_full_crc_sum_www;
	
assign udp_head_crc_sum_w = udp_src_port[15:0] + udp_dst_port[15:0] + tcp_seq_num[31:16] + tcp_seq_num[15:0] + tcp_ack_num[31:16] + tcp_ack_num[15:0] + {tcp_head_len, 6'b0, tcp_flags} 
									+ tcp_window + tcp_urgent_ptr 
									+ ((tcp_head_len >= 4'd8) ? tcp_options[95:80] : 16'h0) 
									+ ((tcp_head_len >= 4'd8) ? tcp_options[79:64] : 16'h0)
									+ ((tcp_head_len >= 4'd7) ? tcp_options[63:48] : 16'h0)
									+ ((tcp_head_len >= 4'd7) ? tcp_options[47:32] : 16'h0)
									+ ((tcp_head_len >= 4'd6) ? tcp_options[31:16] : 16'h0)
									+ ((tcp_head_len >= 4'd6) ? tcp_options[15: 0] : 16'h0);

assign udp_head_crc_sum_ww = udp_head_crc_sum_w[31:16] + udp_head_crc_sum_w[15:0];
assign udp_head_crc_sum_www = udp_head_crc_sum_ww[31:16] + udp_head_crc_sum_ww[15:0];
	
	
/*assign udp_full_crc_sum_w = pseudo_crc_sum_www[15:0] + udp_head_crc_sum_www[15:0] + udp_data_chksum[15:0];
assign udp_full_crc_sum_ww = udp_full_crc_sum_w[31:16] + udp_full_crc_sum_w[15:0];
assign udp_full_crc_sum_www = udp_full_crc_sum_ww[31:16] + udp_full_crc_sum_ww[15:0];*/
assign udp_full_crc_sum_w =	//preudo header crc sum
										ip_src_addr_r[31:16] + ip_src_addr_r[15:0] + ip_dst_addr_r[31:16] + ip_dst_addr_r[15:0] + ip_prot_r[7:0] + (udp_data_length_r + tcp_head_len_r * 4'd4) +
										//tcp header crc sum
										udp_src_port_r[15:0] + udp_dst_port_r[15:0] + tcp_seq_num_r[31:16] + tcp_seq_num_r[15:0] + tcp_ack_num_r[31:16] + tcp_ack_num_r[15:0] + {tcp_head_len_r, 6'b0, tcp_flags_r} +
										tcp_window_r + tcp_urgent_ptr_r +
										((tcp_head_len >= 4'd6) ? tcp_options_r[95:80] : 16'h0) +
										((tcp_head_len >= 4'd6) ? tcp_options_r[79:64] : 16'h0) +
										((tcp_head_len >= 4'd7) ? tcp_options_r[63:48] : 16'h0) +
										((tcp_head_len >= 4'd7) ? tcp_options_r[47:32] : 16'h0) +
										((tcp_head_len >= 4'd8) ? tcp_options_r[31:16] : 16'h0) +
										((tcp_head_len >= 4'd8) ? tcp_options_r[15: 0] : 16'h0) +
										//data crc sum
										udp_data_chksum[15:0];
										
assign udp_full_crc_sum_ww = udp_full_crc_sum_w[31:16] + udp_full_crc_sum_w[15:0];
assign udp_full_crc_sum_www = udp_full_crc_sum_ww[31:16] + udp_full_crc_sum_ww[15:0];

assign work_o = work_r;




endmodule
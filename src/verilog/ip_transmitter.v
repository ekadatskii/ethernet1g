module ip_transmitter
(
	input				clk
	,input			rst_n
	
	//control signals
	,input					ip_start
	
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
	,output					ip_busy	
	
	//output data + controls
	,output	[31:0]		ip_data_out
	,output	[ 1:0]		ip_be_out
	,output					ip_data_out_rdy
	,input					ip_data_out_sel
	,input					ip_data_out_rd
);

reg				ip_work_r;
reg				ip_data_out_rdy_r;

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

reg	[3 :0]	ip_head_ptr;

wire				ip_stop;

//IP WORK SIGNAL
always @(posedge clk or negedge rst_n)
	if (!rst_n)				ip_work_r <= 1'b0;
	else if (ip_stop)		ip_work_r <= 1'b0;
	else if (ip_start)	ip_work_r <= 1'b1;
	
//IP VERSION REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_version_r <= 4'b0;
	else if (ip_start & !ip_work_r)	ip_version_r <= ip_version;
	
//IP HEADER LENGTH REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_head_len_r <= 4'b0;
	else if (ip_start & !ip_work_r)	ip_head_len_r <= ip_head_len;
	
//IP DIFFERENTIATED SERVICE FIELD REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_dsf_r <= 8'b0;
	else if (ip_start & !ip_work_r)	ip_dsf_r <= ip_dsf;
	
//IP TOTAL LENGTH REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_total_len_r <= 16'b0;
	else if (ip_start & !ip_work_r)	ip_total_len_r <= ip_total_len;
	
//IP IDENTIFICATION LENGTH REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_id_r <= 16'b0;
	else if (ip_start & !ip_work_r)	ip_id_r <= ip_id;
	
//IP FLAG REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_flag_r <= 3'b0;
	else if (ip_start & !ip_work_r)	ip_flag_r <= ip_flag;
	
//IP FRAGMENT OFFSET REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_frag_offset_r <= 13'b0;
	else if (ip_start & !ip_work_r)	ip_frag_offset_r <= ip_frag_offset;
	
//IP TIME TO LIVE REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_ttl_r <= 8'b0;
	else if (ip_start & !ip_work_r)	ip_ttl_r <= ip_ttl;
	
//IP PROTOCOL REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_prot_r <= 8'b0;
	else if (ip_start & !ip_work_r)	ip_prot_r <= ip_prot;
	
//IP HEADER CHECKSUM REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_head_chksum_r <= 16'b0;
	else if (ip_start & !ip_work_r)	ip_head_chksum_r <= ip_head_chksum;		//TODO
	
//IP SOURCE ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_src_addr_r <= 32'b0;
	else if (ip_start & !ip_work_r)	ip_src_addr_r <= ip_src_addr;
	
//IP DESTINATION ADDRESS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_dst_addr_r <= 32'b0;
	else if (ip_start & !ip_work_r)	ip_dst_addr_r <= ip_dst_addr;
	
//IP OPTIONS REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)								ip_options_r <= 32'b0;
	else if (ip_start & !ip_work_r)	ip_options_r <= ip_options;
	
	
//IP HEADER POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)																ip_head_ptr <= 4'b0;
	else if (ip_stop)														ip_head_ptr <= 4'b0;
	else if (ip_work_r & ip_data_out_sel & ip_data_out_rd)	ip_head_ptr <= ip_head_ptr + 4'd1;

//IP FRAGMENT SEND STOP
assign ip_stop = ip_work_r & ip_data_out_sel & ip_data_out_rd & ((ip_head_ptr + 4'd1) == ip_head_len_r);

//IP OUT DATA READY
always @(posedge clk or negedge rst_n)
	if (!rst_n)				ip_data_out_rdy_r <= 1'b0;
	else if (ip_stop)		ip_data_out_rdy_r <= 1'b0;
	else if (ip_start)	ip_data_out_rdy_r <= 1'b1;

//Output signals
assign ip_busy = 				ip_work_r;
assign ip_data_out_rdy =	ip_data_out_rdy_r;
assign ip_data_out =			(ip_head_ptr == 4'd0) ?	{ip_version_r, ip_head_len_r, ip_dsf_r, ip_total_len_r} :
									(ip_head_ptr == 4'd1) ? {ip_id_r, ip_flag_r, ip_frag_offset} :
									(ip_head_ptr == 4'd2) ? {ip_ttl_r, ip_prot_r, ip_head_chksum_r} :
									(ip_head_ptr == 4'd3) ? ip_src_addr_r :
									(ip_head_ptr == 4'd4) ? ip_dst_addr_r :
									(ip_head_ptr == 4'd5) ? ip_options_r :
									32'h0;

//IP BYTE ENABLE									
assign ip_be_out = 			2'b00;


endmodule
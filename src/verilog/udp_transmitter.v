module udp_transmitter
(
	input				clk
	,input			rst_n
	
	//control signals
	,input					udp_start
	
	//packet parameters
	,input	[15:0]		udp_src_port
	,input	[15:0]		udp_dst_port
	,input	[15:0]		udp_data_length
//	,input	[15:0]		udp_chksum		TODO

	//status signals
	,output					udp_busy
	
	//input data
	,input	[31:0]		udp_data_in
	,output					udp_data_in_rd
	
	//output data + controls
	,output	[31:0]		udp_data_out
	,output	[ 1:0]		udp_be_out
	,output					udp_data_out_rdy
	,input					udp_data_out_sel
	,input					udp_data_out_rd
);

reg				udp_work_r;
reg				udp_data_out_rdy_r;
reg				udp_data_rcv_ph;
reg				udp_data_snd_ph;

reg	[15:0]	udp_src_port_r;	
reg	[15:0]	udp_dst_port_r;
reg	[15:0]	udp_length_r;
reg	[15:0]	udp_chksum_r;
reg	[31:0]	udp_data_r;

reg	[16:0]	udp_data_ptr;

wire				udp_stop;

//UDP WORK SIGNAL
always @(posedge clk or negedge rst_n)
	if (!rst_n)				udp_work_r <= 1'b0;
	else if (udp_stop)	udp_work_r <= 1'b0;
	else if (udp_start)	udp_work_r <= 1'b1;
	
//UDP SOURCE REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									udp_src_port_r <= 16'b0;
	else if (udp_start & !udp_work_r)	udp_src_port_r <= udp_src_port;
	
//UDP DESTINATION REGISTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									udp_dst_port_r <= 16'b0;
	else if (udp_start & !udp_work_r)	udp_dst_port_r <= udp_dst_port;

//UDP LENGTH REGISTER(data length + udp packet data length(8 bytes))
always @(posedge clk or negedge rst_n)
	if (!rst_n)									udp_length_r <= 16'b0;
	else if (udp_start & !udp_work_r)	udp_length_r <= udp_data_length + 16'd8;

//UDP DATA POINTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)																	udp_data_ptr <= 17'b0;
	else if (udp_stop)														udp_data_ptr <= 17'b0;
	else if (udp_work_r & udp_data_out_sel & udp_data_out_rd)	udp_data_ptr <= udp_data_ptr + 4'd4;

//UDP FRAGMENT SEND STOP
assign udp_stop = udp_work_r & udp_data_out_sel & udp_data_out_rd & ((udp_data_ptr + 4'd4) >= udp_length_r);

//UDP OUT DATA READY
always @(posedge clk or negedge rst_n)
	if (!rst_n)				udp_data_out_rdy_r <= 1'b0;
	else if (udp_stop)	udp_data_out_rdy_r <= 1'b0;
	else if (udp_start)	udp_data_out_rdy_r <= 1'b1;
	
//UDP DATA RECEIVE PHASE
always @(posedge clk or negedge rst_n)
	if (!rst_n)																	udp_data_rcv_ph <= 1'b0;
	else if (udp_stop)														udp_data_rcv_ph <= 1'b0;
	else if (udp_work_r & udp_data_out_sel & udp_data_out_rd)	udp_data_rcv_ph <= 1'b1;

//UDP DATA REG
always @(posedge clk or negedge rst_n)
	if (!rst_n)																			udp_data_r <= 32'b0;
	else if (udp_stop)																udp_data_r <= 32'b0;
	else if (udp_data_rcv_ph & udp_data_out_sel & udp_data_out_rd)		udp_data_r <= udp_data_in;

//UDP DATA SEND PHASE
always @(posedge clk or negedge rst_n)
	if (!rst_n)																							udp_data_snd_ph <= 1'b0;
	else if (udp_stop)																				udp_data_snd_ph <= 1'b0;
	else if (udp_work_r & udp_data_rcv_ph & udp_data_out_sel & udp_data_out_rd)	udp_data_snd_ph <= 1'b1;

//UDP CHECKSUM
always @(posedge clk or negedge rst_n)			//TODO
	if (!rst_n)	udp_chksum_r <= 16'b0;

//Output signals
assign udp_busy = 			udp_work_r;
assign udp_data_out_rdy =	udp_data_out_rdy_r;
assign udp_data_out =		(udp_data_snd_ph) 							? udp_data_r :
									(udp_data_rcv_ph & !udp_data_snd_ph)	? {udp_length_r, udp_chksum_r} :
									(udp_work_r & !udp_data_rcv_ph)			? {udp_src_port_r, udp_dst_port_r} : 32'h0;

//UDP BYTE ENABLE									
assign udp_be_out = 			(udp_data_snd_ph & ((udp_data_ptr + 3'd1) == udp_length_r)) ? 2'b01 :
									(udp_data_snd_ph & ((udp_data_ptr + 3'd2) == udp_length_r)) ? 2'b10 :
									(udp_data_snd_ph & ((udp_data_ptr + 3'd3) == udp_length_r)) ? 2'b11 :
									(udp_data_snd_ph)	? 2'b00 :
									(udp_data_rcv_ph & !udp_data_snd_ph)	? 2'b00 :
									(udp_work_r & !udp_data_rcv_ph)			? 2'b00 : 
									2'b00;

//UDP INPUT DATA READ
assign udp_data_in_rd = udp_data_rcv_ph & udp_data_out_sel & udp_data_out_rd;


endmodule
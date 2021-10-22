module eth1g_transmitter
(

	input				clk
	,input			rst_n
	
	

);

mac_head_transmitter mac_head_transmitter
(
	.clk						(clk)
	,.rst_n					(rst_n)
	
	//control signals
	,.mac_start				()
	
	//packet parameters
	,.mac_src_addr			()				//i48
	,.mac_dst_addr			()				//i48
	,.mac_type				()				//i16
	
	//status signals
	,.mac_busy				()
	
	//output data + controls
	,.mac_data_out			()				//o32
	,.mac_be_out			()
	,.mac_data_out_rdy	()
	,.mac_data_out_sel	()
	,.mac_data_out_rd		()
);

ip_transmitter ip_transmitter
(
	.clk						(clk)
	,.rst_n					(rst_n)
	
	//control signals
	,.ip_start				()
	
	//packet parameters
	,.ip_version			()		//i4
	,.ip_head_len			()		//i4
	,.ip_dsf					()		//i8
	,.ip_total_len			()		//i16
	,.ip_id					()		//i16
	,.ip_flag				()		//i3
	,.ip_frag_offset		()		//i13
	,.ip_ttl					()		//i8
	,.ip_prot				()		//i8
	,.ip_head_chksum		()		//i16
	,.ip_src_addr			()		//i32
	,.ip_dst_addr			()		//i32
	,.ip_options			()		//i32
	
	//status signals
	,.ip_busy				()
	
	//output data + controls
	,.ip_data_out			()
	,.ip_be_out				()
	,.ip_data_out_rdy		()
	,.ip_data_out_sel		()
	,.ip_data_out_rd		()
);

udp_transmitter udp_transmitter
(
	.clk						(clk)
	,.rst_n					(rst_n)
	
	//control signals
	,.udp_start				()
	
	//packet parameters
	,.udp_src_port			()		//i16
	,.udp_dst_port			()		//i16
	,.udp_data_length		()		//i16
//	,input	[15:0]		udp_chksum

	//status signals
	,.udp_busy				()
	
	//input data
	,.udp_data_in			()
	,.udp_data_in_rd		()
	
	//output data + controls
	,.udp_data_out			()
	,.udp_be_out			()
	,.udp_data_out_rdy	()
	,.udp_data_out_sel	()
	,.udp_data_out_rd		()
);





endmodule
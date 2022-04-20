module tcp_controller #(parameter MEMORY_NUM, parameter LOCAL_PORT)
(
	input						clk
	,input					rst_n

	//INPUT PARAMETERS FROM TCP RECEIVED PACKET
	,input					tcp_op_rcv_i
	,input	[15:0]		tcp_source_port_i
	,input	[15:0]		tcp_dest_port_i
	,input	[ 5:0]		tcp_flags_i
	,input	[95:0]		tcp_options_i
	,input	[31:0]		tcp_seq_num_i
	,input	[31:0]		tcp_ack_num_i
	,input	[15:0]		tcp_data_len_i
	,input	[15:0]		tcp_window_i
	,output					tcp_new_pckt_rd_o
	
	,input	[15:0]		ram_dat_len_i
	,input	[31:0]		resend_time_i
	
	,output	[31:0]		rcv_ack_num_o
	,output	[ 5:0]		rcv_flags_o
	,output					tcp_new_pckt_rcv_o
	
	//OUTPUT PARAMETERS TO SEND TCP PACKET
	,output	[15:0]		tcp_source_port_o
	,output	[15:0]		tcp_dest_port_o
	,output	[ 5:0]		tcp_flags_o
	,output	[31:0]		tcp_seq_num_o
	,output	[31:0]		tcp_ack_num_o
	,output	[ 3:0]		tcp_head_len_o
	,output					ctrl_cmd_start_o
	,output	[15:0]		tcp_data_len_o
	,input					tcp_wdat_stop_i
	,input	[ 3:0]		tcp_options_len_i
	,output	[31:0]		tcp_seq_num_next_o

	
	,output					tcp_wdat_start_o
	,input					trnsmt_busy_i
	,output					tcp_state_listen_o
	,output					tcp_state_estblsh_o
	
	,input	[MEMORY_NUM-1 :0]	mem_wr_lock_flg_i
	,input	[MEMORY_NUM-1 :0] mem_rd_lock_flg_i
	,input	[MEMORY_NUM-1 :0] mem_rd_seq_lock_flg_i
	,input	[MEMORY_NUM-1 :0] med_rd_ack_i
	,output	[MEMORY_NUM-1 :0] mem_data_sel_o
	
/*	
	,output	[31:0]		test_o
	,output	[31:0]		tet2_o
	,output	[31:0]		test3_o
	,output	[31:0]		test4_o
	,output	[31:0]		test5_o
*/
	
);

localparam			STATE_LISTEN		= 7'b000_0001;
localparam			STATE_SYN_RCVD		= 7'b000_0010;
localparam			STATE_ESTABLISHED	= 7'b000_0100;
localparam			STATE_CLOSE_WAIT	= 7'b000_1000;	
localparam			STATE_LAST_ACK		= 7'b001_0000;
localparam			STATE_CLOSED		= 7'b010_0000;
//localparam			STATE_FINWAIT1	= 7'b000_0100;
//localparam			STATE_FINWAIT2	= 7'b000_0100;
//localparam			STATE_CLOSING	= 7'b000_0100;
//localparam			STATE_TIMEWAIT	= 7'b000_0100;

reg	[ 7:0]	state;
reg				sack_start;
reg				fin_start;
reg				ack_start;
reg				wdat_start;
reg				rst_start;
reg				wdat_lock;
reg				ctrl_dat_lock;
reg	[ 5:0]	tcp_flags_r;
reg	[31:0]	tcp_seq_num_r;
reg	[31:0]	tcp_ack_num_r;
reg	[ 3:0]	tcp_head_len_r;
reg	[15:0]	tcp_data_len_r;
reg	[4:0]		tcp_packet_counter;
reg	[31:0]	tcp_window_r;
reg	[31:0]	ISS;					//initial sequence number
reg	[31:0]	SND_NEXT;			//next sequence number
reg	[31:0]	ACK_NEXT;
reg	[31:0]	SND_UNA;				//unacknowledged sequence number
reg				tcp_op_rcv_rd_r;
reg	[31:0]	time_out_r;
reg	[15:0]	tcp_dest_port_r;
reg	[15:0]	tcp_src_port_r;
reg				new_data_rd_r;
reg				new_data_rdy_r;
reg				new_data_use_r;
reg	[31:0]	new_seq_num_r;
reg	[31:0]	new_ack_num_r;
reg	[15:0]	new_data_len_r;
reg	[ 5:0]	new_flags_r;
reg	[15:0]	new_window_r;
reg	[15:0]	new_src_port_r;
reg	[15:0]	new_dst_port_r;


//TCP FLAGS
//	FLAG[5]	|	FLAG[4]	|	FLAG[3]	|	FLAG[2]	|	FLAG[1]	|	FLAG[0]
//	URGENT	|	ACK		|	PUSH		|	RST		|	SYN		|	FIN

wire				flag_urg_i;
wire				flag_ack_i;
wire				flag_psh_i;
wire				flag_rst_i;
wire				flag_syn_i;
wire				flag_fin_i;

wire				syn_rcv;
wire				ack_rcv;
wire				fin_rcv;
wire				fin_ack_rcv;
wire				rst_rcv;
wire				push_rcv;
wire				port_hit;

wire	[31:0]	tcp_ack_num_diff;
wire				time_out_pas;

reg	[MEMORY_NUM-1:	0]	mem_dat_rdy;
reg	[MEMORY_NUM-1:	0]	mem_old_dat_all_flg;
reg							mem_old_dat_flg;
wire							mem_old_dat_any_flg;
wire							mem_dat_any_flg;
wire							mem_sel_rdy;
wire 							sel_block;
wire							port_mask_change;
wire							wdat_stop;
wire							mem_notack_sel_rdy;

reg	[MEMORY_NUM-1 :0] mem_notack_dat_rdy;
wire	[MEMORY_NUM-1 :0] mem_notack_dat_sel;
reg							mem_notack_dat_stop;
wire	[MEMORY_NUM-1:	0]	mem_notack_port_mask;

wire							next_pckt_hit_w;
wire	[31:0]				next_seq_num_w;
wire							new_data_rd_w;

/*
reg	[31:0]	test3_o_r;
reg	[31:0]	test4_o_r;
reg	[31:0]	test5_o_r;*/

//----------------------------------------------------------------------------------------------//
//									INTERMEDIATE BUFFER BETWEEN FIFO AND CONTROLLER							   //
//----------------------------------------------------------------------------------------------//
//READ NEW DATA
assign new_data_rd_w	= 	(tcp_op_rcv_i & !new_data_rdy_r &((state == STATE_LISTEN)			| 
																			 (state == STATE_SYN_RCVD) 		| 
																			 (state == STATE_CLOSE_WAIT)		| 
																			 (state == STATE_LAST_ACK) 		| 
																			 (state == STATE_CLOSED)			|
																			 (state == STATE_ESTABLISHED)))	|
																			 
(tcp_op_rcv_i & next_pckt_hit_w & (state == STATE_ESTABLISHED) & port_hit & !((new_data_len_r != 0) & (tcp_data_len_i == 0)) &
														 !tcp_flags_i[2] & !tcp_flags_i[1] & !tcp_flags_i[0] & 
														 !new_flags_r[2] & !new_flags_r[1] & !new_flags_r[0]
														 );

//NEW DATA READY FLAG
always @(posedge clk or negedge rst_n)
	if (!rst_n)																				
													new_data_rdy_r <= 1'b0;
	//READ NEW DATA IF NO UNREQUESTED DATA
	else if (tcp_op_rcv_i & !new_data_rdy_r & ((state == STATE_LISTEN)		| 
															 (state == STATE_SYN_RCVD) 	| 
															 (state == STATE_CLOSE_WAIT)	| 
															 (state == STATE_LAST_ACK) 	| 
															 (state == STATE_CLOSED)		|
															 ((state == STATE_ESTABLISHED) & port_hit) |
															 ((state == STATE_ESTABLISHED) & tcp_flags_i[1])
															 ))	
													new_data_rdy_r <= 1'b1;
													
	//READ NEW DATA IF ACK FLAG HIT and SEQ_NUM BELONGS TO THE NEXT PACKET and DATA_LEN not changed or become not NULL(only ESTABLISHED state) 
	else if (tcp_op_rcv_i & !tcp_flags_i[2] & !tcp_flags_i[1] & !tcp_flags_i[0] & !new_flags_r[2] & !new_flags_r[1] & !new_flags_r[0] & next_pckt_hit_w & !((new_data_len_r != 0) & (tcp_data_len_i == 0)) & (state == STATE_ESTABLISHED) & port_hit)
													new_data_rdy_r <= 1'b1;
	//CLEAR WHEN DATA USED(NOT CLEAR IF NEW RIGHT DATA OR ACK IN ESTABLISHED STATE RECEIVED)
	else if (tcp_op_rcv_rd_r)
													new_data_rdy_r <= 1'b0;

//NEXT PACKET SEQUENCE NUMBER HIT
assign next_seq_num_w	= (new_seq_num_r + new_data_len_r);
							
//NEXT PACKET SEQUENCE NUMBER HIT						
assign next_pckt_hit_w	= (next_seq_num_w == tcp_seq_num_i);

//PORT HIT
assign port_hit = (tcp_src_port_r == tcp_source_port_i);
				
//NEW DATA LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n)					new_data_len_r <= 0;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & port_hit) 		new_data_len_r <= tcp_data_len_i;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & tcp_flags_i[1]) new_data_len_r <= tcp_data_len_i;
	else if ((state != STATE_ESTABLISHED) & new_data_rd_w)						new_data_len_r <= tcp_data_len_i;
	
//NEW DATA FLAGs
always @(posedge clk or negedge rst_n)
	if (!rst_n)					new_flags_r <= 0;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & port_hit) 		new_flags_r <= tcp_flags_i;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & tcp_flags_i[1]) new_flags_r <= tcp_flags_i;
	else if ((state != STATE_ESTABLISHED) & new_data_rd_w)						new_flags_r <= tcp_flags_i;

//NEW DATA SEQUENCE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)					new_seq_num_r <= 0;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & port_hit) 		new_seq_num_r <= tcp_seq_num_i;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & tcp_flags_i[1]) new_seq_num_r <= tcp_seq_num_i;
	else if ((state != STATE_ESTABLISHED) & new_data_rd_w)						new_seq_num_r <= tcp_seq_num_i;

//NEW DATA ACKNOWLEDGE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)					new_ack_num_r <= 0;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & port_hit) 		new_ack_num_r <= tcp_ack_num_i;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & tcp_flags_i[1]) new_ack_num_r <= tcp_ack_num_i;
	else if ((state != STATE_ESTABLISHED) & new_data_rd_w)						new_ack_num_r <= tcp_ack_num_i;
	
//NEW DATA WINDOW
always @(posedge clk or negedge rst_n)
	if (!rst_n)					new_window_r <= 0;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & port_hit) 		new_window_r <= tcp_window_i;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & tcp_flags_i[1]) new_window_r <= tcp_window_i;
	else if ((state != STATE_ESTABLISHED) & new_data_rd_w)						new_window_r <= tcp_window_i;
	
//NEW SOURCE PORT
always @(posedge clk or negedge rst_n)
	if (!rst_n)					new_src_port_r <= 0;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & port_hit) 		new_src_port_r <= tcp_source_port_i;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & tcp_flags_i[1]) new_src_port_r <= tcp_source_port_i;
	else if ((state != STATE_ESTABLISHED) & new_data_rd_w)						new_src_port_r <= tcp_source_port_i;
	
//NEW DEST PORT
always @(posedge clk or negedge rst_n)
	if (!rst_n)					new_dst_port_r <= 0;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & port_hit) 		new_dst_port_r <= tcp_dest_port_i;
	else if ((state == STATE_ESTABLISHED) & new_data_rd_w & tcp_flags_i[1]) new_dst_port_r <= tcp_dest_port_i;
	else if ((state != STATE_ESTABLISHED) & new_data_rd_w)						new_dst_port_r <= tcp_dest_port_i;

													
//----------------------------------------------------------------------//
//									CONTROLLER MAIN									   //
//----------------------------------------------------------------------//
													

//GENERATING INITIAL SEQUENCE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)		ISS <= 0;
	else				ISS <= 0;
	
//NEXT SEQUENCE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									SND_NEXT <= 0;
	else if (state == STATE_LISTEN)		SND_NEXT <= ISS + 1'b1;
	
//UNACKNOWLEDGED SEQUENCE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)									SND_UNA <= 0;
	else if (state == STATE_LISTEN)		SND_UNA <= ISS;	

//READ RECEIVED OPERATION
always @(posedge clk or negedge rst_n)
	if (!rst_n)									tcp_op_rcv_rd_r <= 1'b0;
	else if (tcp_op_rcv_rd_r)				tcp_op_rcv_rd_r <= 1'b0;
	else if (!wdat_start & !ctrl_cmd_start_o & !trnsmt_busy_i & new_data_rdy_r)
													tcp_op_rcv_rd_r <= 1'b1;												
	
//TCP STATE CONTROLLER
always @(posedge clk or negedge rst_n)
	if (!rst_n)		state <= STATE_LISTEN;
	else 
			case(state)
					//----------------------
					STATE_LISTEN:
						begin
							if (rst_rcv)						state <= STATE_LISTEN;							
							else if (syn_rcv & !ack_rcv)	state <= STATE_SYN_RCVD;
							//Если пришел Ack, то отправить сигнал <ACK+RST. SEQ=SEG.ACK>
							//Cформировать ISS - initial sequence number(Алгоритм реализовать позже или не реализовывать)
							//Переменная SND.NEXT <= ISS+1
							//SND.UNA <= ISS - send unacknowledged
						end

					//----------------------
					STATE_SYN_RCVD:
						begin
							if (rst_rcv)		state <= STATE_LISTEN;
							else if (syn_rcv)	state <= STATE_CLOSED;
							else if (ack_rcv)	state <= STATE_ESTABLISHED;
						end

					//----------------------	
					STATE_ESTABLISHED:
						begin
							if (rst_rcv)		state <= STATE_CLOSED;
							else if (syn_rcv)	state <= STATE_CLOSED;
							else if (fin_rcv)	state <= STATE_CLOSE_WAIT;
						end
					//----------------------
					STATE_CLOSE_WAIT:
						begin
							if (rst_rcv)		state <= STATE_CLOSED;										
							else 					state <= STATE_LAST_ACK;
						end

					//----------------------
					STATE_LAST_ACK:
						begin
							if (rst_rcv)		state <= STATE_CLOSED;
							else if (ack_rcv)	state <= STATE_CLOSED;
							else if (syn_rcv)	state <= STATE_CLOSED;
						end
						
					//----------------------
					STATE_CLOSED:
						begin
								state <= STATE_LISTEN;
						end					
			endcase
			
//SYN RECEIVED			
assign syn_rcv 		= new_flags_r[1] & new_data_rdy_r & tcp_op_rcv_rd_r;
//ACK RECEIVED
assign ack_rcv 		= new_flags_r[4] & new_data_rdy_r & tcp_op_rcv_rd_r;
//FIN RECEIVED
assign fin_rcv			= new_flags_r[0] & new_data_rdy_r & tcp_op_rcv_rd_r;
//RST RECEIVED
assign rst_rcv			= new_flags_r[2] & new_data_rdy_r & tcp_op_rcv_rd_r;
//PUSH RECEIVED
assign push_rcv		= new_flags_r[3] & new_data_rdy_r & tcp_op_rcv_rd_r;


//START SYN+ACK SEND WHEN SYN RECEIVED
always @(posedge clk or negedge rst_n)
	if (!rst_n)												sack_start <= 1'b0;
	else if (sack_start)									sack_start <= 1'b0;
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))	
																sack_start <= 1'b1;

//START FIN WHEN CONNECTION CLOSE
always @(posedge clk or negedge rst_n)
	if (!rst_n)												fin_start <= 1'b0;
	else if (fin_start)									fin_start <= 1'b0;
	else if (state == STATE_CLOSE_WAIT)				fin_start <= 1'b1;
	
//START ACK WHEN DATA RECEIVED
always @(posedge clk or negedge rst_n)
	if (!rst_n)												ack_start <= 1'b0;
	else if (ack_start)									ack_start <= 1'b0;
	else if (ack_rcv & !fin_rcv & !rst_rcv & (new_data_len_r != 0) & (state == STATE_ESTABLISHED))
																ack_start <= 1'b1;
	else if (ack_rcv & !fin_rcv & !rst_rcv & mem_old_dat_flg & !time_out_pas_w & (state == STATE_ESTABLISHED))
																ack_start <= 1'b1;
	else if (ack_rcv & !fin_rcv & !rst_rcv & !mem_old_dat_flg & mem_old_dat_any_flg & (state == STATE_ESTABLISHED))
																ack_start <= 1'b1;																

//START RESET SEND
always @(posedge clk or negedge rst_n)
	if (!rst_n)												rst_start <= 1'b0;
	else if (rst_start)									rst_start <= 1'b0;
/*	else if (ack_rcv & (state == STATE_LISTEN))
																rst_start <= 1'b1;*/
	else if (new_data_rdy_r & tcp_op_rcv_rd_r & !rst_rcv & (state == STATE_CLOSED))
																rst_start <= 1'b1;											

//START WRITE DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n)												wdat_start <= 1'b0;
	else if (state == STATE_CLOSED)					wdat_start <= 1'b0;	
	else if (wdat_start)									wdat_start <= 1'b0;	
	else if (!new_data_rdy_r & !ctrl_cmd_start_o & !wdat_lock & !trnsmt_busy_i /*& (tcp_packet_counter < 16)*/ & (tcp_window_r > 25000) & (state == STATE_ESTABLISHED) & mem_sel_rdy & !mem_old_dat_flg)
																wdat_start <= 1'b1;
	else if (!new_data_rdy_r & !ctrl_cmd_start_o & !wdat_lock & !trnsmt_busy_i & (state == STATE_ESTABLISHED) & mem_sel_rdy & mem_old_dat_flg & time_out_pas_w)
																wdat_start <= 1'b1;																
																
//LOCK WRITE DATA	
always @(posedge clk or negedge rst_n)
	if (!rst_n)												wdat_lock <= 1'b0;
	else if (state == STATE_CLOSED)					wdat_lock <= 1'b0;
	else if (tcp_wdat_stop_i & (state == STATE_ESTABLISHED))
																wdat_lock <= 1'b0;	
	else if (wdat_start)		
																wdat_lock <= 1'b1;												

//TCP FLAGS REG FOR WRITE OPERATIONS
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_flags_r <= 6'h0;
	//RST RECEIVED
	else if (rst_rcv)
																tcp_flags_r <= 6'h00;
	//RST+ACK WHEN ACK RECEIVED IN LISTEN STATE
	else if (ack_rcv & (state == STATE_LISTEN))	
																tcp_flags_r <= 6'h14;
	//SYN+ACK SEND WHEN SYN RECEIVED
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))	
																tcp_flags_r <= 6'h12;															

	else if (wdat_start & (state == STATE_ESTABLISHED))
																tcp_flags_r <= 6'h18;

	else if (ack_rcv & !fin_rcv & (state == STATE_ESTABLISHED))
																tcp_flags_r <= 6'h10;
																
	else if (state == STATE_CLOSE_WAIT)				tcp_flags_r <= 6'h11;																

	else if (new_data_rdy_r & tcp_op_rcv_rd_r & !rst_rcv & ack_rcv & (state == STATE_CLOSED))
																tcp_flags_r <= 6'h14;
	else if (new_data_rdy_r & tcp_op_rcv_rd_r & !rst_rcv & !ack_rcv & (state == STATE_CLOSED))
																tcp_flags_r <= 6'h04;
																
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_src_port_r <= 0;
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))
																tcp_src_port_r <= new_src_port_r;																
	
//INPUT ACKNOWLEDGEMENT NUMBER
/*
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_ack_num_in_r <= 32'h0000_0000;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)		tcp_ack_num_in_r <= tcp_ack_num_i;*/
	
//NEXT RECEIVE ACKNOWLEDGE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)												ACK_NEXT <= 0;
	else if (ack_rcv & (state == STATE_SYN_RCVD))ACK_NEXT <= new_seq_num_r + new_data_len_r;
	else if (ack_rcv & (state == STATE_ESTABLISHED) & (new_seq_num_r == ACK_NEXT))
																ACK_NEXT <= new_seq_num_r + new_data_len_r;


//TCP SEQUENCE NUMBER FOR WRITE
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_seq_num_r <= 32'h0000_0000;
	else if (rst_rcv)
																tcp_seq_num_r <= tcp_seq_num_r;
																
	else if (ack_rcv & (state == STATE_LISTEN))	
																tcp_seq_num_r <= new_ack_num_r;
																
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))		
																tcp_seq_num_r <= ISS;						//tcp_seq_num_i;//ISS;//tcp_seq_num_r + 1'b1;
																
	else if (ack_rcv & (state == STATE_SYN_RCVD))
																tcp_seq_num_r <= tcp_seq_num_r + 1'b1;
																
	else if (tcp_wdat_stop_i & wdat_lock & (state == STATE_ESTABLISHED) & !mem_old_dat_flg)
																tcp_seq_num_r <= tcp_seq_num_r + ram_dat_len_i;
																													
	else if (state == STATE_CLOSE_WAIT)				
																tcp_seq_num_r <= tcp_seq_num_r;																

	else if (new_data_rdy_r & tcp_op_rcv_rd_r & !rst_rcv & ack_rcv & (state == STATE_CLOSED))
																tcp_seq_num_r <= new_ack_num_r;

	else if (new_data_rdy_r & tcp_op_rcv_rd_r & !rst_rcv & !ack_rcv & (state == STATE_CLOSED))
																tcp_seq_num_r <= tcp_seq_num_r;															


//TCP ACKNOWLEDGMENT NUMBER FOR WRITE
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_ack_num_r <= 32'h0000_0000;
	
	else if (rst_rcv)
																tcp_ack_num_r <= new_seq_num_r;
	
	else if (ack_rcv & (state == STATE_LISTEN))
																tcp_ack_num_r <= new_seq_num_r;
																
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))	
																tcp_ack_num_r <= new_seq_num_r + 1'b1;
																
	else if (fin_rcv & (state == STATE_ESTABLISHED))
																tcp_ack_num_r <= new_seq_num_r + 1'b1;
																
	else if (ack_rcv & (state == STATE_ESTABLISHED)) //& (new_seq_num_r == ACK_NEXT))
																tcp_ack_num_r <= new_seq_num_r + new_data_len_r;
																
	else if (new_data_rdy_r & tcp_op_rcv_rd_r & !rst_rcv & !ack_rcv & (state == STATE_CLOSED))
																tcp_ack_num_r <= new_seq_num_r + new_data_len_r;																	

//TCP HEADER LENGTH FOR WRITE
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_head_len_r <= (4'd05 + tcp_options_len_i);
	else if (state == STATE_CLOSED)					tcp_head_len_r <= (4'd05 + tcp_options_len_i);
	else if (ack_rcv & (state == STATE_LISTEN))
																tcp_head_len_r <= 4'd05;

	else if (state == STATE_ESTABLISHED)
																tcp_head_len_r <= 4'd05;

																
//TCP DATA LENGTH FOR WRITE
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_data_len_r <= 16'd00;
	else if (state == STATE_LISTEN)
																tcp_data_len_r <= 16'd00;																
	else if (rst_rcv)
																tcp_data_len_r <= 16'd00;
																
	else if (wdat_start & (state == STATE_ESTABLISHED))
																tcp_data_len_r <= ram_dat_len_i;

	else if (ack_rcv & (new_data_len_r != 0) & (state == STATE_ESTABLISHED))
																tcp_data_len_r <= 16'd00;
																
	else if (fin_rcv & (state == STATE_ESTABLISHED))
																tcp_data_len_r <= 16'd00;
																
	else if (state == STATE_CLOSED)
																tcp_data_len_r <= 16'd00;																
																

//TCP PACKET COUNTER	TO CONTROL NUMBER OF PACKETS UNTIL ACK RECEIVED							//TODO??????
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_packet_counter <= 5'd0;
	else if (state == STATE_CLOSED)					tcp_packet_counter <= 5'd0;	

	else if (ack_rcv & (state == STATE_ESTABLISHED))												
																tcp_packet_counter <= 5'd0;
	else if (state == STATE_LISTEN)					tcp_packet_counter <= 5'd0;
	else if (wdat_start)									tcp_packet_counter <= tcp_packet_counter + 1'b1;

//WINDOW SIZE RECEIVE FOR BUFFER LOAD CONTROL
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_window_r <= 32'd0;
	
	else if (new_data_rdy_r & tcp_op_rcv_rd_r & (state == STATE_SYN_RCVD))
																tcp_window_r <= {16'b0, new_window_r};
																
	else if (new_data_rdy_r & tcp_op_rcv_rd_r  & (state == STATE_ESTABLISHED))
																tcp_window_r <= new_ack_num_r + new_window_r - tcp_seq_num_r;

/*
always @(posedge clk or negedge rst_n)
	if (!rst_n)																test3_o_r <= 32'b0;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)						test3_o_r <= tcp_seq_num_r;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																test4_o_r <= 32'b0;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)						test4_o_r <= tcp_ack_num_in_r;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																test5_o_r <= 32'b0;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)						test5_o_r <= {test5_o_r[15:0], tcp_window_r};*/
	
//TIMER
always @(posedge clk or negedge rst_n)
	if (!rst_n)	
					time_out_r <= 0;
	else if (!mem_old_dat_flg)
					time_out_r <= 0;
					
	else if ((state == STATE_ESTABLISHED) & wdat_start & mem_old_dat_flg)
					time_out_r <= resend_time_i;
					
	else if (!time_out_pas_w)
					time_out_r <= time_out_r - 1'b1;
					
assign time_out_pas_w = time_out_r == 0;

//----------------------------------------------------------------------------------//
//									MEMORY DATA SELECTORs AND ARBITERS							   //
//----------------------------------------------------------------------------------//
//MEMORY DATA READY
always @*
begin: mem_dat_ready
	integer r;
	mem_dat_rdy = {MEMORY_NUM{1'b0}};
	for ( r = 0; r < MEMORY_NUM; r = r + 1 )
		begin
			mem_dat_rdy[r] = mem_wr_lock_flg_i[r] & !mem_rd_lock_flg_i[r];
		end
end
								
//SELECTED DATA OLD
always @*
begin: mem_dat_old
	integer i;
	mem_old_dat_flg = 1'b0;
	for ( i = 0; i < MEMORY_NUM; i = i + 1 )
		if (mem_data_sel_o[i])
		begin
			mem_old_dat_flg = mem_rd_seq_lock_flg_i[i];
		end
end

//MEMORY OLD ALL FLAGS
always @*
begin: mem_old_dat_all
	integer k;
	mem_old_dat_all_flg = {MEMORY_NUM{1'b0}};
	for ( k = 0; k < MEMORY_NUM; k = k + 1 )
		begin
			mem_old_dat_all_flg[k] = !mem_rd_lock_flg_i[k] & mem_rd_seq_lock_flg_i[k];
		end
end

//MEMORY ANY FLAG
assign mem_dat_any_flg = |mem_dat_rdy;

//MEMORY OLD ANY FLAG			
assign mem_old_dat_any_flg =	|mem_old_dat_all_flg;
										
//NOT ACKNOWLEDGED MEMORY SELECT STOP(ACK)
always @*
begin: mem_notack_stop
	integer j;
	mem_notack_dat_stop = 1'b0;
	for ( j = 0; j < MEMORY_NUM; j = j + 1 )
		if (mem_notack_dat_sel[j])
		begin
			mem_notack_dat_stop = med_rd_ack_i[j];
		end
end
	
//NOT ACKNOWLEDGED MEMORY DATA READY	
always @*
begin: mem_notack_data_ready
	integer n;
	mem_notack_dat_rdy = {MEMORY_NUM{1'b0}};
	for ( n = 0; n < MEMORY_NUM; n = n + 1 )
		begin
			mem_notack_dat_rdy[n] = mem_wr_lock_flg_i[n] & mem_rd_lock_flg_i[n];
		end
end								
									
//BLOCK SELECT IN ARBITER WHEN IRQs NOT READY OR CONTROLLER IN PROCESS
assign sel_block = ((state != STATE_ESTABLISHED) | new_data_rdy_r | trnsmt_busy_i | wdat_start | !time_out_pas_w);

//CHANGE ARBITER PORT MASK TO SELECT NEXT OLD UNACK DATA MEMORY
assign port_mask_change = (state != STATE_ESTABLISHED) & mem_notack_sel_rdy;

//STOP DATA SEND
assign wdat_stop = tcp_wdat_stop_i & wdat_lock;

//MEMORY DATA SELECT
tcp_mem_arbiter #(MEMORY_NUM) tcp_mem_arbiter
(
	.clk						(		clk							)
	,.rst_n					(		rst_n							)
	
	//Connection with controllers
	,.sel_block_i			(		sel_block					)
	,.irq_i					(		mem_dat_rdy					)
	,.irq_repeat_i			(		mem_old_dat_flg			)
	,.irq_any_repeat_i	(		mem_old_dat_any_flg		)
	,.sel_o					(		mem_data_sel_o				)
	,.sel_rdy_o				(		mem_sel_rdy					)									
	
	,.port_mask_i			(		mem_notack_port_mask		)	
	,.port_mask_chng_i	(		port_mask_change			)	
		
	//Connection with encoder
	,.stop_i					(		wdat_stop					)	
);	

//MEMORY NOT ACKNOWLEDGED ARBITER

tcp_unconf_mem_arbiter #(MEMORY_NUM) tcp_mem_notack_arbiter
(
	.clk						(		clk							)
	,.rst_n					(		rst_n							)
	
	
	//Connection with controllers
	,.irq_i					(		mem_notack_dat_rdy		)
	,.sel_o					(		mem_notack_dat_sel		)	
	,.sel_rdy_o				(		mem_notack_sel_rdy		)											
	,.port_mask_o			(		mem_notack_port_mask		)
		
	//Connection with encoder
	,.stop_i					( 		mem_notack_dat_stop		)
);
											
//OUTPUT SIGNALS	
assign tcp_wdat_start_o			= wdat_start;
assign tcp_data_len_o			= tcp_data_len_r;
assign tcp_flags_o				= tcp_flags_r;
assign ctrl_cmd_start_o			= sack_start | fin_start | ack_start | rst_start;
assign tcp_source_port_o		= LOCAL_PORT;
assign tcp_dest_port_o			= tcp_src_port_r;
assign tcp_seq_num_o				= tcp_seq_num_r;
assign tcp_ack_num_o				= tcp_ack_num_r;
assign tcp_head_len_o			= tcp_head_len_r;
assign tcp_new_pckt_rd_o		= new_data_rd_w;
assign tcp_new_pckt_rcv_o		= tcp_op_rcv_rd_r;
assign tcp_state_listen_o		= (state == STATE_LISTEN);
assign tcp_state_estblsh_o		= (state == STATE_ESTABLISHED);
assign tcp_seq_num_next_o		= tcp_seq_num_r;
assign rcv_ack_num_o				= new_ack_num_r;
assign rcv_flags_o				= new_flags_r;
/*
assign test_o = tcp_ack_num_diff;
assign tet2_o = {31'b0, {(tcp_window_r < 6000)}};
assign test3_o =test3_o_r;
assign test4_o =test4_o_r;
assign test5_o =test5_o_r;
assign tcp_ack_num_diff = (tcp_seq_num_r > tcp_ack_num_in_r) ? (tcp_seq_num_r - tcp_ack_num_in_r) : (tcp_ack_num_in_r - tcp_seq_num_r);*/


endmodule
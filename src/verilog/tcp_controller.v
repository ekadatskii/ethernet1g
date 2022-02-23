`define DATA_TX
module tcp_controller #(parameter MEMORY_NUM)
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
	,output					tcp_op_rcv_rd_o
	
	//INPUT FLAGS/DATA PARAMETERS FROM MUX
//	,input					ram_dat_rdy_i
//	,input					ram_oldseq_flg_i
	,input	[15:0]		ram_dat_len_i
	
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

localparam TCP_DATA_LENGTH_IN_BYTE = 16'd1450;

localparam [15:0]	LOCAL_PORT = 16'hF718; //63256

localparam			STATE_LISTEN		= 7'b000_0001;
localparam			STATE_SYN_RCVD		= 7'b000_0010;
localparam			STATE_ESTABLISHED	= 7'b000_0100;
//localparam			STATE_FINWAIT1	= 7'b000_0100;
//localparam			STATE_FINWAIT2	= 7'b000_0100;
//localparam			STATE_CLOSING	= 7'b000_0100;
//localparam			STATE_TIMEWAIT	= 7'b000_0100;
localparam			STATE_CLOSE_WAIT	= 7'b000_1000;	//
localparam			STATE_LAST_ACK		= 7'b001_0000;	//
localparam			STATE_CLOSED		= 7'b010_0000;

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
reg	[31:0]	tcp_seq_num_in_r;
reg	[31:0]	tcp_ack_num_in_r;
reg	[ 3:0]	tcp_head_len_r;
reg	[15:0]	tcp_data_len_r;
reg	[4:0]		tcp_packet_counter;
reg	[31:0]	tcp_window_r;
reg	[31:0]	ISS;	//initial sequence number
reg	[31:0]	SND_NEXT;	//next sequence number
reg	[31:0]	ACK_NEXT;
reg	[31:0]	SND_UNA;		//unacknowledged sequence number
reg				tcp_op_rcv_rd_r;
reg	[31:0]	time_out_r;
reg	[15:0]	tcp_dest_port_r;
reg	[15:0]	tcp_src_port_r;


reg	[31:0]	test3_o_r;
reg	[31:0]	test4_o_r;
reg	[31:0]	test5_o_r;

//reg				old_data_en;
//reg				old_data_start;
//reg				old_data_lock;

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

wire	[31:0]	tcp_ack_num_diff;
wire				time_out_pas;

wire	[MEMORY_NUM-1:	0]	mem_dat_rdy;
wire							mem_old_dat_flg;
wire							mem_old_dat_any_flg;
wire							mem_sel_rdy;

wire	[MEMORY_NUM-1 :0] mem_notack_dat_rdy;
wire	[MEMORY_NUM-1 :0] mem_notack_dat_sel;
wire							mem_notack_dat_stop;
wire	[MEMORY_NUM-1:	0]	mem_notack_port_mask;



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
	else if (!wdat_start & !ctrl_cmd_start_o & !trnsmt_busy_i & tcp_op_rcv_i)
													tcp_op_rcv_rd_r <= 1'b1;
/*
//OLD DATA ENABLE FLAG
always @(posedge clk or negedge rst_n)
	if (!rst_n)									old_data_en <= 1'b0;
	else if ((state == STATE_LISTEN) & ram_lock_any_i)	
													old_data_en <= 1'b1;
	else if ((state == STATE_ESTABLISHED) & !ram_lock_any_i)
													old_data_en <= 1'b0;
*/													

	

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
							if (rst_rcv & (tcp_src_port_r == tcp_source_port_i))		state <= STATE_CLOSED;				
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
						end
						
					//----------------------
					STATE_CLOSED:
						begin
								state <= STATE_LISTEN;
						end					
			endcase
			
//SYN RECEIVED			
assign syn_rcv 		= tcp_flags_i[1] & tcp_op_rcv_i & tcp_op_rcv_rd_o;
//ACK RECEIVED
assign ack_rcv 		= tcp_flags_i[4] & tcp_op_rcv_i & tcp_op_rcv_rd_o;
//FIN RECEIVED
assign fin_rcv			= tcp_flags_i[0] & tcp_op_rcv_i & tcp_op_rcv_rd_o;
//RST RECEIVED
assign rst_rcv			= tcp_flags_i[2] & tcp_op_rcv_i & tcp_op_rcv_rd_o;

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
	else if (ack_rcv & !fin_rcv  & (tcp_data_len_i != 0) & (state == STATE_ESTABLISHED))
																ack_start <= 1'b1;

//START RESET SEND
always @(posedge clk or negedge rst_n)
	if (!rst_n)												rst_start <= 1'b0;
	else if (rst_start)									rst_start <= 1'b0;
	else if (ack_rcv & (state == STATE_LISTEN))
																rst_start <= 1'b1;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o & !rst_rcv & (state == STATE_CLOSED))
																rst_start <= 1'b1;
																
//LOCK CONTROL DATA
/*
always @(posedge clk or negedge rst_n)
	if (!rst_n)												ctrl_dat_lock <= 1'b0;
	else if (sack_start | fin_start | ack_start | rst_start)
																ctrl_dat_lock <= 1'b1;
	else if ()*/


//START WRITE DATA
always @(posedge clk or negedge rst_n)
	if (!rst_n)												wdat_start <= 1'b0;
	else if (state == STATE_CLOSED)					wdat_start <= 1'b0;	
	else if (wdat_start)									wdat_start <= 1'b0;
	else if (!tcp_op_rcv_i & !ctrl_cmd_start_o & !wdat_lock & !trnsmt_busy_i & (tcp_packet_counter < 16) & (tcp_window_r > 25000) & (state == STATE_ESTABLISHED) & mem_sel_rdy & !mem_old_dat_flg)//TODO may be for old data need another window size or packet counter
																wdat_start <= 1'b1;
	else if (!tcp_op_rcv_i & !ctrl_cmd_start_o & !wdat_lock & !trnsmt_busy_i & (state == STATE_ESTABLISHED) & mem_sel_rdy & mem_old_dat_flg & time_out_pas_w)
																wdat_start <= 1'b1;																
																
//LOCK WRITE DATA	
always @(posedge clk or negedge rst_n)
	if (!rst_n)												wdat_lock <= 1'b0;
	else if (state == STATE_CLOSED)					wdat_lock <= 1'b0;
	else if (tcp_wdat_stop_i & (state == STATE_ESTABLISHED))//(ack_rcv & !fin_rcv & (state == STATE_ESTABLISHED))
																wdat_lock <= 1'b0;	
	else if (wdat_start)		
																wdat_lock <= 1'b1;												

//TCP FLAGS REG FOR WRITE OPERATIONS
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_flags_r <= 6'h0;
//RST+ACK WHEN ACK RECEIVED IN LISTEN STATE
	else if (ack_rcv & (state == STATE_LISTEN))	
																tcp_flags_r <= 6'h14;
//SYN+ACK SEND WHEN SYN RECEIVED
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))	
																tcp_flags_r <= 6'h12;															

	else if (wdat_start & (state == STATE_ESTABLISHED))
																tcp_flags_r <= 6'h18;
/*	else if (old_data_start & (state == STATE_ESTABLISHED))
																tcp_flags_r <= 6'h18;*/
	else if (ack_rcv & !fin_rcv & (state == STATE_ESTABLISHED))
																tcp_flags_r <= 6'h10;
																
	else if (state == STATE_CLOSE_WAIT)				tcp_flags_r <= 6'h11;																

	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o & !rst_rcv & ack_rcv & (state == STATE_CLOSED))
																tcp_flags_r <= 6'h14;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o & !rst_rcv & !ack_rcv & (state == STATE_CLOSED))
																tcp_flags_r <= 6'h04;
																
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_src_port_r <= 0;
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))
																tcp_src_port_r <= tcp_source_port_i;
																
//INPUT SEQUENCE NUMBER			//??????????????????
/*
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_seq_num_in_r <= 32'h0000_0000;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)		tcp_seq_num_in_r <= tcp_seq_num_i;
*/	
	
//INPUT ACKNOWLEDGEMENT NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_ack_num_in_r <= 32'h0000_0000;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)		tcp_ack_num_in_r <= tcp_ack_num_i;
	
//NEXT RECEIVE ACKNOWLEDGE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)												ACK_NEXT <= 0;
	else if (ack_rcv & (state == STATE_SYN_RCVD))ACK_NEXT <= tcp_seq_num_i + tcp_data_len_i;
	else if (ack_rcv & (state == STATE_ESTABLISHED) & (tcp_seq_num_i == ACK_NEXT))
																ACK_NEXT <= tcp_seq_num_i + tcp_data_len_i;


//TCP SEQUENCE NUMBER FOR WRITE
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_seq_num_r <= 32'h0000_0000;																//mem_old_dat_flg
	else if (ack_rcv & (state == STATE_LISTEN))	
																tcp_seq_num_r <= tcp_ack_num_i;//tcp_seq_num_r + 1'b1;
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))		
																tcp_seq_num_r <= ISS;//tcp_seq_num_i;//ISS;//tcp_seq_num_r + 1'b1;
	else if (ack_rcv & (state == STATE_SYN_RCVD))
																tcp_seq_num_r <= tcp_seq_num_r + 1'b1;
																
	else if (tcp_wdat_stop_i & wdat_lock & (state == STATE_ESTABLISHED) & !mem_old_dat_flg)
																tcp_seq_num_r <= tcp_seq_num_r + ram_dat_len_i;
																
/*																
	else if (old_data_en & !rst_rcv & ack_rcv & (tcp_seq_num_r + 16'd1450 <= tcp_ack_num_i) & (state == STATE_ESTABLISHED))
																tcp_seq_num_r <= tcp_seq_num_r + TCP_DATA_LENGTH_IN_BYTE;*/													
																
	else if (state == STATE_CLOSE_WAIT)				
																tcp_seq_num_r <= tcp_seq_num_r;																

	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o & !rst_rcv & ack_rcv & (state == STATE_CLOSED))
																tcp_seq_num_r <= tcp_ack_num_i;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o & !rst_rcv & !ack_rcv & (state == STATE_CLOSED))
																tcp_seq_num_r <= tcp_seq_num_r;															

																
//TCP ACKNOWLEDGMENT NUMBER FOR WRITE
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_ack_num_r <= 32'h0000_0000;
	else if (ack_rcv & (state == STATE_LISTEN))
																tcp_ack_num_r <= tcp_seq_num_i;
	else if (syn_rcv & !ack_rcv & (state == STATE_LISTEN))	
																tcp_ack_num_r <= tcp_seq_num_i + 1'b1;
	else if (fin_rcv & (state == STATE_ESTABLISHED))
																tcp_ack_num_r <= tcp_seq_num_i + 1'b1;
	else if (ack_rcv & (state == STATE_ESTABLISHED) & (tcp_seq_num_i == ACK_NEXT))
																tcp_ack_num_r <= tcp_seq_num_i + tcp_data_len_i;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o & !rst_rcv & !ack_rcv & (state == STATE_CLOSED))
																tcp_ack_num_r <= tcp_seq_num_i + tcp_data_len_i;																	

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
//`ifdef DATA_TX
	else if (wdat_start & (state == STATE_ESTABLISHED))
																tcp_data_len_r <= ram_dat_len_i;//TCP_DATA_LENGTH_IN_BYTE;
/*
	else if (old_data_start & (state == STATE_ESTABLISHED))
																tcp_data_len_r <= TCP_DATA_LENGTH_IN_BYTE;																
*/																
//`else
	else if (ack_rcv & (tcp_data_len_i != 0) & (state == STATE_ESTABLISHED))
																tcp_data_len_r <= 16'd00;
//`endif															
	else if (fin_rcv & (state == STATE_ESTABLISHED))
																tcp_data_len_r <= 16'd00;
	else if (state == STATE_CLOSED)
																tcp_data_len_r <= 16'd00;																
																

//TCP PACKET COUNTER	TO CONTROL NUMBER OF PACKETS UNTIL ACK RECEIVED
/*															
always @(posedge clk or negedge rst_n)
	if (!rst_n)												tcp_packet_counter <= 5'd0;
	else if (ack_rcv & (state == STATE_ESTABLISHED) & (tcp_seq_num_r == tcp_ack_num_i))
																tcp_packet_counter <= 5'd0;
	else if (state == STATE_LISTEN)					tcp_packet_counter <= 5'd0;
	else if (wdat_start)									tcp_packet_counter <= tcp_packet_counter + 1'b1;*/
	
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
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o & (state == STATE_SYN_RCVD))
																tcp_window_r <= {16'b0, tcp_window_i};
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o  & (state == STATE_ESTABLISHED))
																tcp_window_r <= tcp_ack_num_i + tcp_window_i - tcp_seq_num_r;
	
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																test3_o_r <= 32'b0;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)						test3_o_r <= tcp_seq_num_r;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																test4_o_r <= 32'b0;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)						test4_o_r <= tcp_ack_num_in_r;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)																test5_o_r <= 32'b0;
	else if (tcp_op_rcv_i & tcp_op_rcv_rd_o)						test5_o_r <= {test5_o_r[15:0], tcp_window_r};
	
//TIMER
always @(posedge clk or negedge rst_n)
	if (!rst_n)	
					time_out_r <= 0;
	else if (!mem_old_dat_flg)
					time_out_r <= 0;
					
	else if ((state == STATE_ESTABLISHED) & wdat_start & mem_old_dat_flg)
					time_out_r <= 32'd200_000_000;
					
	else if (!time_out_pas_w)
					time_out_r <= time_out_r - 1'b1;
					
assign time_out_pas_w = time_out_r == 0;

//---------------------------------------------------------------------//
//									DATA SELECTOR										  //
//---------------------------------------------------------------------//
//MEMORY DATA READY
assign mem_dat_rdy = {
									(mem_wr_lock_flg_i[15] & !mem_rd_lock_flg_i[15]),
									(mem_wr_lock_flg_i[14] & !mem_rd_lock_flg_i[14]),
									(mem_wr_lock_flg_i[13] & !mem_rd_lock_flg_i[13]),
									(mem_wr_lock_flg_i[12] & !mem_rd_lock_flg_i[12]),
									(mem_wr_lock_flg_i[11] & !mem_rd_lock_flg_i[11]),
									(mem_wr_lock_flg_i[10] & !mem_rd_lock_flg_i[10]),
									(mem_wr_lock_flg_i[9] & !mem_rd_lock_flg_i[9]),
									(mem_wr_lock_flg_i[8] & !mem_rd_lock_flg_i[8]),
									(mem_wr_lock_flg_i[7] & !mem_rd_lock_flg_i[7]),
									(mem_wr_lock_flg_i[6] & !mem_rd_lock_flg_i[6]),
									(mem_wr_lock_flg_i[5] & !mem_rd_lock_flg_i[5]),
									(mem_wr_lock_flg_i[4] & !mem_rd_lock_flg_i[4]),
									(mem_wr_lock_flg_i[3] & !mem_rd_lock_flg_i[3]),
									(mem_wr_lock_flg_i[2] & !mem_rd_lock_flg_i[2]),
									(mem_wr_lock_flg_i[1] & !mem_rd_lock_flg_i[1]),
									(mem_wr_lock_flg_i[0] & !mem_rd_lock_flg_i[0])
								};
								
//SELECTED DATA OLD								
assign mem_old_dat_flg =	mem_data_sel_o[15] ? mem_rd_seq_lock_flg_i[15] :
									mem_data_sel_o[14] ? mem_rd_seq_lock_flg_i[14] :
									mem_data_sel_o[13] ? mem_rd_seq_lock_flg_i[13] :
									mem_data_sel_o[12] ? mem_rd_seq_lock_flg_i[12] :
									mem_data_sel_o[11] ? mem_rd_seq_lock_flg_i[11] :
									mem_data_sel_o[10] ? mem_rd_seq_lock_flg_i[10] :
									mem_data_sel_o[9] ? mem_rd_seq_lock_flg_i[9] :
									mem_data_sel_o[8] ? mem_rd_seq_lock_flg_i[8] :
									mem_data_sel_o[7] ? mem_rd_seq_lock_flg_i[7] :
									mem_data_sel_o[6] ? mem_rd_seq_lock_flg_i[6] :
									mem_data_sel_o[5] ? mem_rd_seq_lock_flg_i[5] :
									mem_data_sel_o[4] ? mem_rd_seq_lock_flg_i[4] :
									mem_data_sel_o[3] ? mem_rd_seq_lock_flg_i[3] :
									mem_data_sel_o[2] ? mem_rd_seq_lock_flg_i[2] :
									mem_data_sel_o[1] ? mem_rd_seq_lock_flg_i[1] :
									mem_data_sel_o[0] ? mem_rd_seq_lock_flg_i[0] : 								
									1'b0;
									
//MEMORY OLD ANY FLAG			//VERIFY
assign mem_old_dat_any_flg =	(!mem_rd_lock_flg_i[15] & mem_rd_seq_lock_flg_i[15]) |
										(!mem_rd_lock_flg_i[14] & mem_rd_seq_lock_flg_i[14]) |
										(!mem_rd_lock_flg_i[13] & mem_rd_seq_lock_flg_i[13]) |
										(!mem_rd_lock_flg_i[12] & mem_rd_seq_lock_flg_i[12]) |
										(!mem_rd_lock_flg_i[11] & mem_rd_seq_lock_flg_i[11]) |
										(!mem_rd_lock_flg_i[10] & mem_rd_seq_lock_flg_i[10]) |
										(!mem_rd_lock_flg_i[9] & mem_rd_seq_lock_flg_i[9]) |
										(!mem_rd_lock_flg_i[8] & mem_rd_seq_lock_flg_i[8]) |
										(!mem_rd_lock_flg_i[7] & mem_rd_seq_lock_flg_i[7]) |
										(!mem_rd_lock_flg_i[6] & mem_rd_seq_lock_flg_i[6]) |
										(!mem_rd_lock_flg_i[5] & mem_rd_seq_lock_flg_i[5]) |
										(!mem_rd_lock_flg_i[4] & mem_rd_seq_lock_flg_i[4]) |
										(!mem_rd_lock_flg_i[3] & mem_rd_seq_lock_flg_i[3]) |
										(!mem_rd_lock_flg_i[2] & mem_rd_seq_lock_flg_i[2]) |
										(!mem_rd_lock_flg_i[1] & mem_rd_seq_lock_flg_i[1]) |
										(!mem_rd_lock_flg_i[0] & mem_rd_seq_lock_flg_i[0]);
										
//NOT ACKNOWLEDGED MEMORY SELECT STOP(ACK)
assign mem_notack_dat_stop =	mem_notack_dat_sel[15] ? med_rd_ack_i[15]:
										mem_notack_dat_sel[14] ? med_rd_ack_i[14]:
										mem_notack_dat_sel[13] ? med_rd_ack_i[13]:
										mem_notack_dat_sel[12] ? med_rd_ack_i[12]:
										mem_notack_dat_sel[11] ? med_rd_ack_i[11]:
										mem_notack_dat_sel[10] ? med_rd_ack_i[10]:
										mem_notack_dat_sel[9] ? med_rd_ack_i[9]:
										mem_notack_dat_sel[8] ? med_rd_ack_i[8]:
										mem_notack_dat_sel[7] ? med_rd_ack_i[7]:
										mem_notack_dat_sel[6] ? med_rd_ack_i[6]:
										mem_notack_dat_sel[5] ? med_rd_ack_i[5]:
										mem_notack_dat_sel[4] ? med_rd_ack_i[4]:
										mem_notack_dat_sel[3] ? med_rd_ack_i[3]:
										mem_notack_dat_sel[2] ? med_rd_ack_i[2]:
										mem_notack_dat_sel[1] ? med_rd_ack_i[1]:
										mem_notack_dat_sel[0] ? med_rd_ack_i[0]:
										1'b0;	
										
//NOT ACKNOWLEDGED MEMORY DATA READY								
assign mem_notack_dat_rdy	= {
										(mem_wr_lock_flg_i[15] & mem_rd_lock_flg_i[15]),
										(mem_wr_lock_flg_i[14] & mem_rd_lock_flg_i[14]),
										(mem_wr_lock_flg_i[13] & mem_rd_lock_flg_i[13]),
										(mem_wr_lock_flg_i[12] & mem_rd_lock_flg_i[12]),
										(mem_wr_lock_flg_i[11] & mem_rd_lock_flg_i[11]),
										(mem_wr_lock_flg_i[10] & mem_rd_lock_flg_i[10]),
										(mem_wr_lock_flg_i[9] & mem_rd_lock_flg_i[9]),
										(mem_wr_lock_flg_i[8] & mem_rd_lock_flg_i[8]),
										(mem_wr_lock_flg_i[7] & mem_rd_lock_flg_i[7]),
										(mem_wr_lock_flg_i[6] & mem_rd_lock_flg_i[6]),
										(mem_wr_lock_flg_i[5] & mem_rd_lock_flg_i[5]),
										(mem_wr_lock_flg_i[4] & mem_rd_lock_flg_i[4]),
										(mem_wr_lock_flg_i[3] & mem_rd_lock_flg_i[3]),
										(mem_wr_lock_flg_i[2] & mem_rd_lock_flg_i[2]),
										(mem_wr_lock_flg_i[1] & mem_rd_lock_flg_i[1]),
										(mem_wr_lock_flg_i[0] & mem_rd_lock_flg_i[0])
									};								
									
//TODO
wire sel_block = ((state != STATE_ESTABLISHED) | tcp_op_rcv_i | trnsmt_busy_i | wdat_start | !time_out_pas_w);
wire port_mask_change = (state != STATE_ESTABLISHED);

//MEMORY DATA SELECT
tcp_mem_arbiter #(MEMORY_NUM) tcp_mem_arbiter
(
	.clk						(	clk						)
	,.rst_n					(	rst_n						)
	
	//Connection with controllers
	,.sel_block_i			(	sel_block				)
	,.irq_i					(	mem_dat_rdy				)
	,.irq_repeat_i			(	mem_old_dat_flg		)
	,.irq_any_repeat_i	(	mem_old_dat_any_flg	)
	,.sel_o					(	mem_data_sel_o			)
	,.sel_rdy_o				(	mem_sel_rdy				)									
	
	,.port_mask_i			(	mem_notack_port_mask	)	//(	wram_unconf_port_mask)			TODO
	,.port_mask_chng_i	(	port_mask_change		)	//(	tcp_ctrl_state_idle	)
		
	//Connection with encoder
	,.stop_i					(	tcp_wdat_stop_i & wdat_lock		)	//( tcp_run & udp_eop & tcp_ctrl_data_flg )
//	,.stop_i					(	wdat_lock & tcp_wdat_stop_i	)	//( tcp_run & udp_eop & tcp_ctrl_data_flg )
);	

//MEMORY NOT ACKNOWLEDGED ARBITER

tcp_unconf_mem_arbiter #(MEMORY_NUM) tcp_mem_notack_arbiter
(
	.clk						(	clk						)
	,.rst_n					(	rst_n						)
	
	//Connection with end controller
	,.wr_allow_i			(	1'b1						)
	
	//Connection with controllers
	
	,.irq_i					(	mem_notack_dat_rdy	)	
	,.sel_o					(	mem_notack_dat_sel	)	
	,.sel_rdy_o				(								)											
	
	,.port_mask_chng_i	(	1'b0						)
	,.port_mask_o			(	mem_notack_port_mask	)
		
	//Connection with encoder
	,.stop_i					( mem_notack_dat_stop	)
);


	
assign	test3_o =test3_o_r;
assign	test4_o =test4_o_r;
assign	test5_o =test5_o_r;
	
assign tcp_ack_num_diff = (tcp_seq_num_r > tcp_ack_num_in_r) ? (tcp_seq_num_r - tcp_ack_num_in_r) : (tcp_ack_num_in_r - tcp_seq_num_r);
															
	
assign tcp_wdat_start_o			= wdat_start;
//assign old_data_start_o			= old_data_start;
assign tcp_data_len_o			= tcp_data_len_r;
assign tcp_flags_o				= tcp_flags_r;
assign ctrl_cmd_start_o	= sack_start | fin_start | ack_start | rst_start;
assign tcp_source_port_o		= LOCAL_PORT;
assign tcp_dest_port_o			= tcp_src_port_r;
assign tcp_seq_num_o				= tcp_seq_num_r;
assign tcp_ack_num_o				= tcp_ack_num_r;
assign tcp_head_len_o			= tcp_head_len_r;
assign tcp_op_rcv_rd_o			= tcp_op_rcv_rd_r;
assign tcp_state_listen_o		= (state == STATE_LISTEN);
assign tcp_state_estblsh_o		= (state == STATE_ESTABLISHED);
assign tcp_seq_num_next_o		= tcp_seq_num_r;
//assign old_data_en_o				= old_data_en;

assign test_o = tcp_ack_num_diff;
assign tet2_o = {31'b0, {(tcp_window_r < 6000)}};

endmodule
//TCP MEMORY
//FLAGS DESCRIPTION
//data_wr_lock_r, data_rd_lock_r, seq_num_lock_r, rd_op_o
//data_wr_lock_r == 0, rd_op_w == 0 - NEED TO FILL MEMORY
//data_wr_lock_r == 1, rd_op_w == 0 - NEW DATA, NEED TO READ IT
//data_wr_lock_r == 1, rd_op_w == 1 - READING IN PROCESS
//data_wr_lock_r == 1, data_rd_lock_r == 0, seq_num_lock_r == 0 - NEED TO READ DATA WITH NEW GENERATED SEQUENCE NUMBER, NO WRITE
//data_wr_lock_r == 1, data_rd_lock_r == 0, seq_num_lock_r == 1 - NEED TO READ DATA WITH CURRENT SEQUENCE NUMBER, NO WRITE
//data_wr_lock_r == 1, data_rd_lock_r == 1, seq_num_lock_r == 1 - NO READ, NO WRITE. WHAIT ACKNOWLEDGE RECEIVE OR TIMER PAS OR TCP CONTROLLER IDLE STATE
module tcp_wr_memory #(parameter MAX_PACKET_SIZE = 1450)
(
	input						clk
	,input					rst_n
	
	//INPUT DATA
	,input					tcp_rcv_eop_i
	,input					tcp_rcv_rst_flag_i
	,input					tcp_rcv_ack_flag_i
	,input	[31:0]		tcp_rcv_ack_num_i
	,input	[31:0]		tcp_seq_num_next_i
	
	,input					controller_idle_st_i
	,input	[31:0]		seq_num_i
	
	//INPUT DATA FROM DATA GENERATOR OR WORK DATA
	,input	[31:0]		wdat_i
	,input	[15:0]		wdat_chksum_i
	,input	[15:0]		wdat_len_i
	,input					wr_i
	,input					wr_sel_i
	,input					wr_op_stop_i
	,output					wr_lock_flg_o
	
	//OUTPUT DATA
	,input					rd_i
	,input					rd_sel_i
	,output	[31:0]		rdat_o
	,output	[15:0]		rd_chksum_o
	,output	[15:0]		rd_len_o
	,output					rd_lock_flg_o
	,output	[31:0]		rd_seq_num_o
	,output					rd_seq_lock_flg_o
	,input					rd_op_start_i
	,input					rd_op_stop_i
	,output					rd_data_ack_o
);

reg	[ 8:0]	rd_addr_r;
reg	[ 8:0]	wr_addr_r;
reg	[31:0]	seq_num_r;
reg				seq_num_lock_r;
reg	[15:0]	data_chksum_r;
reg	[15:0]	data_len_r;
reg				data_wr_lock_r;
reg				data_rd_lock_r;
reg				data_rd_lock_rr;
reg				wait_ack_timer_on_r;
reg	[31:0]	wait_ack_timer_r;
reg				rd_op_r;

wire				wait_ack_timer_pas_w;

wire	[ 8:0]	rd_addr_w;
wire	[ 8:0]	wr_addr_w;

wire				ram_wr_w;
wire				ram_rd_w;

wire				rd_op_w;
wire				ack_hit_w;

//RAM
//----------------------------------------------------
//2 PORTS RAM WIDTH 32 DEPTH 512 CAPACITY 2048 BYTES
ram2048	ram_data 
(
	.clock 					( clk							)
	,.data 					( wdat_i						)
	,.rdaddress				( rd_addr_w					)
	,.wraddress				( wr_addr_w					)
	,.wren					( ram_wr_w					)
	,.q						( rdat_o						)
);

//WRITE OPERATIONS
//----------------------------------------------------
//WRITE TO RAM SIGNAL(WR)
assign ram_wr_w = wr_i & wr_sel_i & !data_wr_lock_r;


//RAM WRITE ADDRESS
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					wr_addr_r <= 0;
	else if (wr_op_stop_i & wr_sel_i)
					wr_addr_r <= 0;
	else if (ram_wr_w)
					wr_addr_r <= wr_addr_r + 1'b1;
					
assign wr_addr_w = wr_addr_r;


//READ OPERATIONS
//----------------------------------------------------
//READ FROM RAM SIGNAL(RD)
assign ram_rd_w = rd_i & rd_sel_i & !data_rd_lock_r;

//RAM READ ADDRESS
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					rd_addr_r <= 0;
	else if (rd_op_stop_i)
					rd_addr_r <= 0;
	else if (ram_rd_w)
					rd_addr_r <= rd_addr_r + 1'b1;
					
assign rd_addr_w = rd_addr_r + ram_rd_w;


//INPUT PARAMETERS(SEQUENCE NUMBER, LENGTH, CHECKSUM)
//----------------------------------------------------
//SEQUENCE NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					seq_num_r <= 0;
	else if (rd_op_start_i & rd_sel_i & !seq_num_lock_r)
					seq_num_r <= seq_num_i;
		
//DATA LENGTH
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					data_len_r <= 0;
	else if (wr_op_stop_i & wr_sel_i & !data_wr_lock_r)
					data_len_r <= wdat_len_i;

//DATA CHECKSUM
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					data_chksum_r <= 0;
	else if (wr_op_stop_i & wr_sel_i & !data_wr_lock_r)	//TODO MAY BE CHECK CRC HERE?
					data_chksum_r <= wdat_chksum_i;	
		
//CONTROL FLAGS AND STATUS
//----------------------------------------------------
//DATA WRITE LOCKED
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					data_wr_lock_r <= 0;
	//CLEAR WHEN DATA ACKNOWLEDGED	
	else if (tcp_rcv_eop_i & tcp_rcv_ack_flag_i & !tcp_rcv_rst_flag_i & ack_hit_w & !controller_idle_st_i & (data_rd_lock_r | seq_num_lock_r))
					data_wr_lock_r <= 0;
	//SET WHEN WRITE COMPLETE
	else if (wr_op_stop_i & wr_sel_i)
					data_wr_lock_r <= 1;
					
//ACKNOWLEDGE HIT
assign ack_hit_w =	((seq_num_r + data_len_r - 1) < tcp_seq_num_next_i) ? ((seq_num_r + data_len_r - 1) < tcp_rcv_ack_num_i) :
							((seq_num_r + data_len_r - 1) > tcp_seq_num_next_i) ? ((tcp_rcv_ack_num_i <= tcp_seq_num_next_i) & ((seq_num_r + data_len_r - 1) > tcp_rcv_ack_num_i)) :
																									((tcp_rcv_ack_num_i  > tcp_seq_num_next_i) & ((seq_num_r + data_len_r - 1) < tcp_rcv_ack_num_i));
					
//DATA READ LOCKED
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					data_rd_lock_r <= 0;
	//CLEAR WHEN TCP CONTROLLER IN IDLE STATE
	else if (controller_idle_st_i)
					data_rd_lock_r <= 0;
	//CLEAR WHEN DATA ACKNOWLEDGED
	else if (tcp_rcv_eop_i & tcp_rcv_ack_flag_i & !tcp_rcv_rst_flag_i & ack_hit_w)	
					data_rd_lock_r <= 1'b0;
	//TODO CLEAR WHEN TIMER OVER
	else if (wait_ack_timer_pas_w)
					data_rd_lock_r <= 1'b0;
	//SET WHEN READ COMPLETE
	else if (rd_op_stop_i & rd_sel_i & data_wr_lock_r & !seq_num_lock_r)
					data_rd_lock_r <= 1'b1;
					
//DATA READ LOCKED SHIFT
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					data_rd_lock_rr <= 0;
	else
					data_rd_lock_rr <= data_rd_lock_r;

					
//TIMER ON
always @(posedge clk or negedge rst_n)
	if (!rst_n)	
					wait_ack_timer_on_r <= 0;
	//CLEAR WHEN TCP CONTROLLER IN IDLE STATE
	else if (controller_idle_st_i)
					wait_ack_timer_on_r <= 0;
	//CLEAR WHEN DATA ACKNOWLEDGED
	else if (tcp_rcv_eop_i & tcp_rcv_ack_flag_i & !tcp_rcv_rst_flag_i & ack_hit_w)	
					wait_ack_timer_on_r <= 1'b0;
	//SET WHEN DATA READ COMPLETE				
	else if (data_rd_lock_r)
					wait_ack_timer_on_r <= 1'b1;

//TIMER
always @(posedge clk or negedge rst_n)
	if (!rst_n)	
					wait_ack_timer_r <= 32'd200_000_000;
	else if (!data_rd_lock_r)
					wait_ack_timer_r <= 32'd200_000_000;
	else if (wait_ack_timer_pas_w)
					wait_ack_timer_r <= 32'd200_000_000;
	else
					wait_ack_timer_r <= wait_ack_timer_r - 1'b1;

assign wait_ack_timer_pas_w = wait_ack_timer_r == 0;

//SEQUENCE NUMBER LOCK
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					seq_num_lock_r <= 0;
	//CLEAR WHEN TCP CONTROLLER IN IDLE STATE
	else if (controller_idle_st_i)
					seq_num_lock_r <= 0;
	//CLEAR WHEN DATA ACKNOWLEDGED
	else if (tcp_rcv_eop_i & tcp_rcv_ack_flag_i & !tcp_rcv_rst_flag_i & ack_hit_w)
					seq_num_lock_r <= 1'b0;
	//SET WHEN DATA READ COMPLETE				
	else if (rd_op_stop_i & rd_sel_i & data_wr_lock_r)
					seq_num_lock_r <= 1'b1;
					
//READ PROCESS ACTIVE
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					rd_op_r <= 0;
	else if (rd_op_stop_i & rd_sel_i & data_wr_lock_r)
					rd_op_r <= 0;
	else if (rd_op_start_i & rd_sel_i)
					rd_op_r <= 1'b1;
					
assign rd_op_w	= rd_op_r | (rd_op_start_i & rd_sel_i);

//OUTPUT SIGNALS
//----------------------------------------------------
assign wr_lock_flg_o			= data_wr_lock_r;// | rd_op_w;
assign rd_lock_flg_o			= data_rd_lock_r;
assign rd_seq_lock_flg_o	= seq_num_lock_r;
assign rd_seq_num_o			= (!seq_num_lock_r) ? seq_num_i : seq_num_r;
assign rd_chksum_o			= data_chksum_r;
assign rd_len_o 				= data_len_r;
//assign rd_data_ack_o			= !data_rd_lock_r & data_rd_lock_rr;
assign rd_data_ack_o			= data_rd_lock_r & (tcp_rcv_eop_i & tcp_rcv_ack_flag_i & !tcp_rcv_rst_flag_i & ack_hit_w);

endmodule
//---------------------------------------------------------------------------------------------------------------------------//
//																																									  //
//																TCP MEMORY ARBITER																			  //
//																																									  //
//---------------------------------------------------------------------------------------------------------------------------//
//MEMORY SELECT ARBITER TO SEND DATA FROM MEMORY TO TCP TRANSMITTER

module tcp_mem_arbiter #(parameter DEVICE_NUM)
(
	input											clk
	,input										rst_n
	
	//Connection with controllers
	,input										sel_block_i
	,input		[DEVICE_NUM-1:0]			irq_i
	,input										irq_repeat_i
	,input										irq_any_repeat_i
	,output		[DEVICE_NUM-1:0]			sel_o
	,output										sel_rdy_o
	,input										stop_i

	//Change port mask
	,input		[size-1 : 0]				port_mask_i
	,input										port_mask_chng_i
	,output		[size-1 : 0]				port_mask_o

	
	//Additional signals
	,output		[size-1 : 0]				port_number_o
	
	//TEST
/*	,output		[size-1 : 0]				port_num_old_o
	,output		[size-1 : 0]				port_num_cur_o
	,output										port_num_flag_o*/
	
	
);

localparam 	size		= log2(DEVICE_NUM);
localparam 	width		= DEVICE_NUM;

reg	[DEVICE_NUM-1:0]	sel_r;
reg	[size-1 : 0]		port_num;
reg	[size-1 : 0]		port_mask;
reg							irq_select;
reg							irq_select_r;
reg							send_done_r;

wire							send_done;

/*reg	[size-1 : 0]		port_num_old;
reg	[size-1 : 0]		port_num_cur;
reg							port_num_flag;*/
//==========================================================================
// RoundRobin Interrupt select
//==========================================================================
//IRQ selected flag		
always @(posedge clk or negedge rst_n)
	if (!rst_n)			
					irq_select	<= 1'b0;
	//SELECT CLEAR WHEN MASK CHANGE TO OLD UNACK DATA
	else if (port_mask_chng_i)
					irq_select	<= 1'b0;

	//SELECT CLEAR WHEN SEND DONE
	else if (send_done) 
					irq_select <= 1'b0;	
					
	//SELECT SET IF NO BLOCK
	else if (|irq_i & !irq_select & !send_done & !sel_block_i)
    for (n = 0; n < width; n = n + 1)
      if (irq_i[n] & (n < port_mask))
					irq_select <= 1'b1;

integer n;

//Select IRQ number
always @(posedge clk or negedge rst_n)
	if (!rst_n)			
					port_num	<= {size{1'b0}};
	//PORT NUM CLEAR WHEN MASK CHANGE
	else if (port_mask_chng_i)	
					port_num	<= {size{1'b0}};
					
	//PORT NUM SELECT IF NO BLOCK
	else if (|irq_i & !irq_select & !send_done & !sel_block_i)
		for (n = 0; n < width; n = n + 1)
			if (irq_i[n] & (n < port_mask))
					port_num <= n;

//IRQ selected flag with shift(begin)					
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					irq_select_r <= 1'b0;
	else if (port_mask_chng_i)
					irq_select_r <= 1'b0;
					
	//SELECT CLEAR WHEN SEND DONE
	else if (send_done) 
					irq_select_r <= 1'b0;	
	else 
					irq_select_r <= irq_select;

//IRQ MASK
always @(posedge clk or negedge rst_n)
	if (!rst_n)			
					port_mask	<= width;
	//READ MASK FROM ARBITER WITH OLDEST UNACKNOWLEDGED DATA
	else if (port_mask_chng_i)
					port_mask <= port_mask_i;
					
	//CHANGE MASK TO INITIAL STATE IF CURRENT DATA NOT NEED TO RECEND NOW
	//AND ARBITTER STAY AT THE BOTTOM
	else if (irq_select & stop_i & !irq_repeat_i & (port_num == 0))			
					port_mask <= width;	
	//CHANGE MASK TO THE NEXT BOTTOM SELECTED INTERRUPT IF CURRENT DATA NOT NEED TO RECEND NOW
	else if (irq_select & stop_i & !irq_repeat_i)			
					port_mask <= port_num;	
	//MASK STAYS AT IRQ STATE WHEN NEED TO REPEAT DATA SEND
	else if (irq_select & stop_i & irq_repeat_i)			
					port_mask <= port_num + 1'b1;	
	//CHANGE MASK TO INITIAL STATE IF CURRENT DATA NOT NEED TO RECEND NOW
	//AND NO DATA AT THE BOTTOM TO SEND
	else if (!irq_select & !send_done & !irq_repeat_i & !sel_block_i) //& !irq_any_repeat_i
					port_mask <= width;
	//CHANGE MASK TO STATE WHEN NEED TO REPEAT SEND OF THE OLDEST UNACKNOWLEDGED DATA
	else if (!irq_select & !send_done & irq_any_repeat_i & !sel_block_i)
					port_mask <= port_mask_i;
					
//IRQ CURRENT
integer m;

always @(posedge clk or negedge rst_n)
	if (!rst_n) 
					sel_r <= {DEVICE_NUM{1'b0}};
	//SELECT PORT CLEAR WHEN MASK CHANGE
	else if (port_mask_chng_i)
					sel_r <= {DEVICE_NUM{1'b0}};
				
	//SELECT PORT CHANGE WHEN IRQ HIT
	else if (irq_select & !irq_select_r)
		for (m = 0; m < DEVICE_NUM; m = m + 1)
			if (m == port_num) 
					sel_r[m] <= 1'b1;
			else 
					sel_r[m] <= 1'b0;

//SEND DONE WITH SHIFT
//NEED FOR WAIT 1 TICK TO RENEW INPUT IRQs
assign send_done = stop_i | send_done_r;

//STOP SIGNAL REG
always @(posedge clk or negedge rst_n)
	if (!rst_n) 
					send_done_r <= 1'b0;
	else 
					send_done_r <= stop_i;

//==========================================================================
function integer log2 (input integer num);
  begin
  for(log2=0; num>0; log2=log2+1)
    num = num >> 1;
  end
endfunction 

//OUTPUTS
assign sel_o			= sel_r;
assign sel_rdy_o		= irq_select_r;
assign port_number_o = port_num;
assign port_mask_o	= port_mask;

//TEST
/*
always @(posedge clk or negedge rst_n)
  if (!rst_n)			port_num_old <= 0;
  else 					port_num_old <= port_num_cur;
  
always @(posedge clk or negedge rst_n)
  if (!rst_n)			port_num_cur <= 0; 
  else 					port_num_cur <= port_num;
  
assign 					port_num_flag_o = (port_num_old > port_num_cur) ? ((port_num_old - port_num_cur) > 1) : 1'b0;*/
  
 	
endmodule
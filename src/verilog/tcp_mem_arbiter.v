//---------------------------------------------------------------------------------------------------------------------------//
//																																									  //
//																		DEVICE ARBITER																			  //
//																																									  //
//---------------------------------------------------------------------------------------------------------------------------//
//Controller used to multiplex data from different Controllers

module tcp_mem_arbiter #(parameter DEVICE_NUM)
(
	input						clk,
	input						rst_n,
	
	//Connection with controllers
	input										sel_block_i,
	input			[DEVICE_NUM-1:0]		irq_i,
	input										irq_repeat_i,
	input										irq_any_repeat_i,
	output		[DEVICE_NUM-1:0]		sel_o,
	output									sel_rdy_o,

	//Change port mask
	input			[size-1 : 0]			port_mask_i,
	input										port_mask_chng_i,
	output		[size-1 : 0]			port_mask_o,

	
	//Additional signals
	output		[size-1 : 0]			port_number_o,
	
	input										stop_i,
	
	//TEST
	output		[size-1 : 0]			port_num_old_o,
	output		[size-1 : 0]			port_num_cur_o,
	output									port_num_flag_o
	
	
);

localparam 	size = log2(DEVICE_NUM);
localparam 	width = DEVICE_NUM;
localparam 	dwidth = 2 * DEVICE_NUM;

//reg	[DEVICE_NUM-1:0]	irq_in;
//reg							sel_block_in;
reg							irq_lock_in;
reg	[DEVICE_NUM-1:0]	sel_r;
reg	[size-1 : 0]		port_num;
reg	[size-1 : 0]		port_mask;
reg							irq_select;
reg							irq_select_r;
reg							send_done_r;

reg	[size-1 : 0]		port_num_old;
reg	[size-1 : 0]		port_num_cur;
reg							port_num_flag;

wire							send_done;
	
//==========================================================================
// RoundRobin Interrupt select
//==========================================================================
//IRQ selected flag		
always @(posedge clk or negedge rst_n)
	if (!rst_n)			
					irq_select	<= 1'b0;
	else if (port_mask_chng_i)
					irq_select	<= 1'b0;

	//SELECT CLEAR FOR NEW DATA
	else if (send_done) 
					irq_select <= 1'b0;	
					
	else if (|irq_i & !irq_select & !send_done & !sel_block_i)
    for (n = 0; n < width; n = n + 1)
      if (irq_i[n] & (n < port_mask))
					irq_select <= 1'b1;

integer n;

//Select IRQ number
always @(posedge clk or negedge rst_n)
  if (!rst_n)			
					port_num	<= {size{1'b0}};
  else if (port_mask_chng_i)	
					port_num	<= {size{1'b0}};
					
  else if (|irq_i & !irq_select & !send_done & !sel_block_i)
    for (n = 0; n < width; n = n + 1)
      if (irq_i[n] & (n < port_mask))
					port_num <= n;

//IRQ selected flag with begin shift					
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					irq_select_r <= 1'b0;
	else if (port_mask_chng_i)
					irq_select_r <= 1'b0;
					
	//SELECT CLEAR FOR NEW DATA					
	else if (send_done) 
					irq_select_r <= 1'b0;	
	else 
					irq_select_r <= irq_select;

//IRQ MASK
always @(posedge clk or negedge rst_n)
	if (!rst_n)			
					port_mask	<= width;
	else if (port_mask_chng_i)
					port_mask <= port_mask_i;
					
	else if (irq_select & stop_i & !irq_repeat_i & (port_num == 0))			
					port_mask <= width;	
	else if (irq_select & stop_i & !irq_repeat_i)			
					port_mask <= port_num;	
	else if (irq_select & stop_i & irq_repeat_i)			
					port_mask <= port_num + 1'b1;	
	else if (!irq_select & !send_done & !irq_repeat_i & !sel_block_i)		
					port_mask <= width;
	else if (!irq_select & !send_done & irq_any_repeat_i & !sel_block_i)
					port_mask <= port_mask_i;


		

//==========================================================================
//SEND DONE
assign send_done = stop_i | send_done_r;

always @(posedge clk or negedge rst_n)
	if (!rst_n) 
				send_done_r <= 1'b0;
	else 
				send_done_r <= stop_i;


//IRQ CURRENT
integer m;

always @(posedge clk or negedge rst_n)
	if (!rst_n) 
				sel_r <= {DEVICE_NUM{1'b0}};				
	else if (port_mask_chng_i)
				sel_r <= {DEVICE_NUM{1'b0}};
				
	else if (irq_select & !irq_select_r)
		for (m = 0; m < DEVICE_NUM; m = m + 1)
			if (m == port_num) 
				sel_r[m] <= 1'b1;
			else 
				sel_r[m] <= 1'b0;

function integer log2 (input integer num);
  begin
  for(log2=0; num>0; log2=log2+1)
    num = num >> 1;
  end
endfunction 

assign sel_o			= sel_r;
assign sel_rdy_o		= irq_select_r;
assign port_number_o = port_num;
assign port_mask_o	= port_mask;

//TEST
always @(posedge clk or negedge rst_n)
  if (!rst_n)			port_num_old <= 0;
  else 					port_num_old <= port_num_cur;
  
always @(posedge clk or negedge rst_n)
  if (!rst_n)			port_num_cur <= 0; 
  else 					port_num_cur <= port_num;
  
assign 					port_num_flag_o = (port_num_old > port_num_cur) ? ((port_num_old - port_num_cur) > 1) : 1'b0;
  
 	
endmodule
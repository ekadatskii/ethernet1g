//---------------------------------------------------------------------------------------------------------------------------//
//																																									  //
//																		DEVICE ARBITER																			  //
//																																									  //
//---------------------------------------------------------------------------------------------------------------------------//
//Controller used to multiplex data from different Controllers and start 5E4D encoder

module eth_arbiter #(parameter SOURCE_NUM)
(
	input						clk,
	input						rst_n,
	
	//Connection with end controller
	input						wr_allow,
	
	//Connection with controllers
	
	input			[SOURCE_NUM-1:0]		dev_rdy,
	output		[SOURCE_NUM-1:0]		sel,
	
	//Additional signals
	output									sel_flag,
	output		[size-1 : 0]			port_number,
	
	//Connection with encoder
	output reg					start,
	input							stop
);

localparam 	size = log2(SOURCE_NUM);
localparam 	width = SOURCE_NUM;
localparam 	dwidth = 2 * SOURCE_NUM;

reg	[SOURCE_NUM-1:0]	irq_in;
reg	[SOURCE_NUM-1:0]	sel_r;
reg	[size-1 : 0]		port_num;
reg	[size-1 : 0]		port_mask;
reg							irq_select;
reg							irq_select_r;
reg							busy;

wire							send_done;

//RUN ENCODER SIGNAL
always @(posedge clk or negedge rst_n)
	if (!rst_n)											start <= 1'b0;
	else if (start)									start <= 1'b0;
	else if (!busy & irq_select & wr_allow)	start <= 1'b1;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n)			busy <= 1'b0;
	else if (stop)		busy <= 1'b0;
	else if (start) 	busy <= 1'b1;	
	
//==========================================================================
// RoundRobin Interrupt select
//==========================================================================
	
//INTERRUPT REGISTER
generate 
genvar i;
for (i = 0; i < SOURCE_NUM; i = i + 1'b1) begin: gen1
	always @(posedge clk or negedge rst_n)
		if (!rst_n)	irq_in[i] <= 1'b0;
		else 			irq_in[i] <= dev_rdy[i];
end
endgenerate

integer n;

//Select IRQ number
always @(posedge clk or negedge rst_n)
  if (!rst_n)			
					port_num	<= {size{1'b0}};
					
  else if (|irq_in & !irq_select)
    for (n = 0; n < width; n = n + 1)
      if (irq_in[n] & (n < port_mask))
					port_num <= n;
			
//IRQ selected flag		
always @(posedge clk or negedge rst_n)
  if (!rst_n)			
					irq_select	<= 1'b0;
  else if (send_done) 
					irq_select <= 1'b0;	
				
  else if (|irq_in & !irq_select)
    for (n = 0; n < width; n = n + 1)
      if (irq_in[n] & (n < port_mask))
					irq_select <= 1'b1;
					
always @(posedge clk or negedge rst_n)
	if (!rst_n)
					irq_select_r <= 1'b0;
	else if (send_done)
					irq_select_r <= 1'b0;
	else 
					irq_select_r <= irq_select;
				
//IRQ MASK
always @(posedge clk or negedge rst_n)
	if (!rst_n)			
					port_mask	<= width;
	else if ((irq_in == 0) & !irq_select)
					port_mask	<= width;
	else if (irq_select & (port_num == 0))
					port_mask	<= width;
	else if (irq_select)					
					port_mask <= port_num;
	else if (!irq_select & !irq_select_r)
					port_mask	<= width;								
															
//==========================================================================

assign send_done = stop;

//IRQ CURRENT
integer m;

always @(posedge clk or negedge rst_n)	
	if (!rst_n) 
				sel_r <= {SOURCE_NUM{1'b0}};

	else if (irq_select)
		for (m = 0; m < SOURCE_NUM; m = m + 1)
			if ((m == port_num) & send_done) sel_r[m] <= 1'b0;
			else if ((m == port_num) & irq_select) sel_r[m] <= 1'b1;		

function integer log2 (input integer num);
  begin
  for(log2=0; num>0; log2=log2+1)
    num = num >> 1;
  end
endfunction 

assign sel = sel_r;
assign sel_flag = irq_select_r;
assign port_number = port_num;
	
endmodule
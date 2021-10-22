module eth_transmitter_arbiter #(parameter SOURCE_NUMBER = 1)
(
	 input			clk
	,input			rst_n
	,input	[SOURCE_NUMBER-1    :0]	rdy_in
	,input	[SOURCE_NUMBER*32-1 :0]	dat_in
	,input	[SOURCE_NUMBER*2-1  :0]	be_in
	
	
);


reg	[8*8 -1:0]	data_reg;
reg	[2*4 -1:0]	be_reg;
reg	[ 7:0]		data_be_reg;
wire					data_rdy;
wire	[31:0]		data_in_high;
wire	[31:0]		data_in_low;
wire					be_all;


wire	[3:0]	be_high;
wire	[3:0]	be_low;
wire be_high_all;
wire be_low_all;

assign be_high_all = (be_high[3:0] == 0);
assign be_low_all  = (be_low[3:0] == 0);

//DATA HIGH BYTE[3]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[7*8+:8] <= 0;
	else if (data_rdy)							data_reg[7*8+:8] <= data_in_high[3*8+:8];
	
//DATA HIGH BYTE[2]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[6*8+:8] <= 0;
	else if (data_rdy & (be_high_all | (be_high[2])))	
														data_reg[6*8+:8] <= data_in_high[2*8+:8];
//DATA HIGH BYTE[1]													
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[5*8+:8] <= 0;
	else if (data_rdy & (be_high_all | (be_high[1])))	
														data_reg[5*8+:8] <= data_in_high[1*8+:8];
//DATA HIGH BYTE[0]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[4*8+:8] <= 0;
	else if (data_rdy & be_high_all)			data_reg[4*8+:8] <= data_in_high[0*8+:8];


/*

//DATA LOW BYTE[3]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[3*8+:8] <= 0;
	else if (data_rdy)							data_reg[3*8+:8] <= data_in_high[3*8+:8];
	
//DATA LOW BYTE[2]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[2*8+:8] <= 0;
	else if (data_rdy & (!be_high_all & (be_low[2])))	
														data_reg[2*8+:8] <= data_in_high[3*8+:8];
	
//DATA LOW BYTE[1]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[1*8+:8] <= 0;
	else if (data_rdy)							data_reg[1*8+:8] <= data_in_high[3*8+:8];

//DATA LOW BYTE[0]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[0*8+:8] <= 0;
	else if (data_rdy)							data_reg[0*8+:8] <= data_in_high[3*8+:8];
	
	
//DATA BE HIGH[3]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[7] <= 1'b0;
	else if (data_rdy | data_be_reg[3])		data_be_reg[7] <= 1'b1;
	else 												data_be_reg[7] <= 1'b0;

//DATA BE HIGH[2]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[6] <= 1'b0;
	else if (data_rdy & (be_high[2] | data_be_reg[2] | be_high_all))
														data_be_reg[6] <= 1'b1;
	else												data_be_reg[6] <= 1'b0;
	
//DATA BE HIGH[1]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[5] <= 1'b0;
	else if (data_rdy & (be_high[1] | data_be_reg[1] | be_high_all))
														data_be_reg[5] <= 1'b1;
	else												data_be_reg[5] <= 1'b0;
	
//DATA BE HIGH[0]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[4] <= 1'b0;
	else if (data_rdy & (data_be_reg[0] | be_high_all))
														data_be_reg[4] <= 1'b1;
	else												data_be_reg[4] <= 1'b0;
*/
	
	
//DATA BE LOW[3]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[3] <= 1'b0;
	
//DATA BE LOW[2]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[2] <= 1'b0;
	
//DATA BE LOW[1]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[1] <= 1'b0;
	
//DATA BE LOW[0]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_be_reg[0] <= 1'b0;


	




endmodule
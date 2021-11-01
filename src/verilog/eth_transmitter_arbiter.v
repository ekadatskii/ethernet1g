module eth_transmitter_arbiter #(parameter SOURCE_NUMBER = 1)
(
	 input			clk
	,input			rst_n
	,input	[SOURCE_NUMBER-1    :0]	rdy_in
	,input	[SOURCE_NUMBER*32-1 :0]	dat_in
	,input	[SOURCE_NUMBER*2-1  :0]	be_in
	
	
);
//					FIRST WR/RD				//				SECOND WR/RD				//
//----------------------------------------------------------------------//
//	BYTE0	//	BYTE1	//	BYTE2	//	BYTE3	//	BYTE4	//	BYTE5	//	BYTE6	//	BYTE7	//
//----------------------------------------------------------------------//


reg	[8*8 -1:0]	data_reg;
reg	[3:0]			cur_ptr;

wire					data_rdy;
wire	[31:0]		data_in_high;
wire	[31:0]		data_in_low;
wire					be_all;

always @(posedge clk or negedge rst_n)
	if (!rst_n) cur_ptr <= 4'b0;
//	else if () cur_ptr <= 4'b0;

/*
//DATA BYTE[0]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[0*8+:8] <= 0;
	else if (data_rdy & be_high_all)			data_reg[0*8+:8] <= data_in_high[0*8+:8];
	
//DATA BYTE[1]													
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[1*8+:8] <= 0;
	else if (data_rdy & (be_high_all | (be_high[1])))	
														data_reg[1*8+:8] <= data_in_high[1*8+:8];
														
//DATA BYTE[2]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[2*8+:8] <= 0;
	else if (data_rdy & (be_high_all | (be_high[2])))	
														data_reg[2*8+:8] <= data_in_high[2*8+:8];		
			
//DATA BYTE[3]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[3*8+:8] <= 0;
	else if (data_rdy)							data_reg[3*8+:8] <= data_in_high[3*8+:8];	

//DATA BYTE[4]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[4*8+:8] <= 0;
	else if (data_rdy & be_high_all)			data_reg[4*8+:8] <= data_in_high[0*8+:8];	
	
//DATA BYTE[5]													
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[5*8+:8] <= 0;
	else if (data_rdy & (be_high_all | (be_high[1])))	
														data_reg[5*8+:8] <= data_in_high[1*8+:8];
														
//DATA BYTE[6]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[6*8+:8] <= 0;
	else if (data_rdy & (be_high_all | (be_high[2])))	
														data_reg[6*8+:8] <= data_in_high[2*8+:8];													

//DATA BYTE[7]
always @(posedge clk or negedge rst_n)
	if (!rst_n)										data_reg[7*8+:8] <= 0;
	else if (data_rdy)							data_reg[7*8+:8] <= data_in_high[3*8+:8];
*/



	

	



	



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
	
	
/*
	
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

*/
	




endmodule
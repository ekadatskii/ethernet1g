module umio_fifo #(parameter SIZE, parameter WIDTH=8) 
(
			input 						rst_n,
			input 						clk,
			output 	[WIDTH-1:0]		rd_data,
			input		[WIDTH-1:0]		wr_data,
			input 						rd_en,
			input 						wr_en,
			output 						full,
			output 						empty
);


parameter ADDR_WIDTH = log2(SIZE-1);

reg	[WIDTH-1:0]		fifo_ram	[0:SIZE-1];
reg	[ADDR_WIDTH:0]	rd_addr;
reg	[WIDTH-1:0]		rd_data_reg;
reg	[WIDTH-1:0]		bp_reg;
reg						bp_val;
reg	[ADDR_WIDTH:0]	wr_addr;
wire	[ADDR_WIDTH-1:0]	mem_raddr;


always @(posedge clk or negedge rst_n)
	if (!rst_n) rd_addr <= {(ADDR_WIDTH+1){1'b0}};
	else if (rd_en & !empty) rd_addr <= rd_addr + 1'b1;
	
always @(posedge clk or negedge rst_n)
	if (!rst_n) wr_addr <= {(ADDR_WIDTH+1){1'b0}};
	else if (wr_en & !full) wr_addr <= wr_addr + 1'b1;
	
assign full		= (rd_addr[ADDR_WIDTH] != wr_addr[ADDR_WIDTH]) & (rd_addr[ADDR_WIDTH-1:0] == wr_addr[ADDR_WIDTH-1:0]);
assign empty	= (rd_addr == wr_addr);

always @(posedge clk) if (wr_en & !full) fifo_ram[wr_addr] <= wr_data;
always @(posedge clk) rd_data_reg <= fifo_ram[mem_raddr];

assign mem_raddr = rd_en ? (rd_addr[ADDR_WIDTH-1:0] + 1'b1) : rd_addr[ADDR_WIDTH-1:0];

//BYPASS
always @(posedge clk) bp_reg <= wr_data;
always @(posedge clk) bp_val <= wr_en & (wr_addr[ADDR_WIDTH-1:0] == mem_raddr);

assign rd_data = bp_val ? bp_reg : rd_data_reg;

//FOR ADDRESS COUNT
function integer log2 (input integer num);
  begin
  for(log2=0; num>0; log2=log2+1)
    num = num >> 1;
  end
endfunction 
	

endmodule
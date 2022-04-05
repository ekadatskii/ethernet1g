module Reg_int (
input                   Reset                   ,
input                   Clk_reg                 ,
input                   CSB                     ,
input                   WRB                     ,
input           [15:0]  CD_in                   ,
output   reg    [15:0]  CD_out                  ,
input           [7:0]   CA                      ,
                        //Tx host interface 
output          [4:0]   Tx_Hwmark               ,
output          [4:0]   Tx_Lwmark               ,   
output                  pause_frame_send_en     ,               
output          [15:0]  pause_quanta_set        ,
output                  MAC_tx_add_en           ,               
output                  FullDuplex              ,
output          [3:0]   MaxRetry                ,
output          [5:0]   IFGset                  ,
output          [7:0]   MAC_tx_add_prom_data    ,
output          [2:0]   MAC_tx_add_prom_add     ,
output                  MAC_tx_add_prom_wr      ,
output                  tx_pause_en             ,
output                  xoff_cpu                ,
output                  xon_cpu                 ,
                        //Rx host interface     
output                  MAC_rx_add_chk_en       ,   
output          [7:0]   MAC_rx_add_prom_data    ,   
output          [2:0]   MAC_rx_add_prom_add     ,   
output                  MAC_rx_add_prom_wr      ,   
output                  broadcast_filter_en     ,
output          [15:0]  broadcast_bucket_depth              ,
output          [15:0]  broadcast_bucket_interval           ,
output                  RX_APPEND_CRC           ,
output          [4:0]   Rx_Hwmark           ,
output          [4:0]   Rx_Lwmark           ,
output                  CRC_chk_en              ,               
output          [5:0]   RX_IFG_SET              ,
output          [15:0]  RX_MAX_LENGTH           ,// 1518
output          [6:0]   RX_MIN_LENGTH           ,// 64
                        //RMON host interface
output          [5:0]   CPU_rd_addr             ,
output                  CPU_rd_apply            ,
input                   CPU_rd_grant            ,
input           [31:0]  CPU_rd_dout             ,
                        //Phy int host interface     
output                  Line_loop_en            ,
output          [2:0]   Speed                   ,
                        //MII to CPU 
output          [7:0]   Divider                 ,// Divider for the host clock
output          [15:0]  CtrlData                ,// Control Data (to be written to the PHY reg.)
output          [4:0]   Rgad                    ,// Register Address (within the PHY)
output          [4:0]   Fiad                    ,// PHY Address
output                  NoPre                   ,// No Preamble (no 32-bit preamble)
output                  WCtrlData               ,// Write Control Data operation
output                  RStat                   ,// Read Status operation
output                  ScanStat                ,// Scan Status operation
input                   Busy                    ,// Busy Signal
input                   LinkFail                ,// Link Integrity Signal
input                   Nvalid                  ,// Invalid Status (qualifier for the valid scan result)
input           [15:0]  Prsd                    ,// Read Status Data (data read from the PHY)
input                   WCtrlDataStart          ,// This signals resets the WCTRLDATA bit in the MIIM Command register
input                   RStatStart              ,// This signal resets the RSTAT BIT in the MIIM Command register
input                   UpdateMIIRX_DATAReg     ,// Updates MII RX_DATA register with read data
output			[31:0]	timer_check_o,
input							btn1,
input							btn2,
input							btn3,
input							btn4
);

//    RegCPUData U_0_000(Tx_Hwmark                ,7'd000,16'h00FF,Reset,Clk_reg,!WRB,CSB,CA,16'h00FF/*CD_in*/);
    RegCPUData U_0_000(Tx_Hwmark                ,7'd000,16'h00FF,Reset,Clk_reg, cd_wr, !cd_wr, ca_out, cd_out);
    RegCPUData U_0_001(Tx_Lwmark                ,7'd001,16'h0008,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_002(pause_frame_send_en      ,7'd002,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_003(pause_quanta_set         ,7'd003,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_004(IFGset                   ,7'd004,16'h0012,Reset,Clk_reg, cd_wr, !cd_wr, ca_out, cd_out);
//    RegCPUData U_0_004(IFGset                   ,7'd004,16'h0012,Reset,Clk_reg,!WRB,CSB,CA,16'h0012);
//    RegCPUData U_0_004(IFGset                   ,7'd004,16'h000c,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
//    RegCPUData U_0_004(IFGset                   ,7'd018,16'h000c,Reset,Clk_reg,!WRB,CSB,CA,16'd18);
    RegCPUData U_0_005(FullDuplex               ,7'd005,16'h0001,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_006(MaxRetry                 ,7'd006,16'h0002,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_007(MAC_tx_add_en            ,7'd007,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_008(MAC_tx_add_prom_data     ,7'd008,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_009(MAC_tx_add_prom_add      ,7'd009,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_010(MAC_tx_add_prom_wr       ,7'd010,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_011(tx_pause_en              ,7'd011,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_012(xoff_cpu                 ,7'd012,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_013(xon_cpu                  ,7'd013,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_014(MAC_rx_add_chk_en        ,7'd014,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_015(MAC_rx_add_prom_data     ,7'd015,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_016(MAC_rx_add_prom_add      ,7'd016,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_017(MAC_rx_add_prom_wr       ,7'd017,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_018(broadcast_filter_en      ,7'd018,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_019(broadcast_bucket_depth   ,7'd019,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_020(broadcast_bucket_interval,7'd020,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_021(RX_APPEND_CRC            ,7'd021,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_022(Rx_Hwmark                ,7'd022,16'h001a,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_023(Rx_Lwmark                ,7'd023,16'h0010,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_024(CRC_chk_en               ,7'd024,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_025(RX_IFG_SET               ,7'd025,16'h000c,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_026(RX_MAX_LENGTH            ,7'd026,16'h2710,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_027(RX_MIN_LENGTH            ,7'd027,16'h0040,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_028(CPU_rd_addr              ,7'd028,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_029(CPU_rd_apply             ,7'd029,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
//  RegCPUData U_0_030(CPU_rd_grant             ,7'd030,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
//  RegCPUData U_0_031(CPU_rd_dout_l            ,7'd031,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
//  RegCPUData U_0_032(CPU_rd_dout_h            ,7'd032,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_033(Line_loop_en             ,7'd033,16'h0000,Reset,Clk_reg,!WRB,CSB,CA,CD_in);
    RegCPUData U_0_034(Speed                    ,7'd034,16'h0004,Reset,Clk_reg,!WRB,CSB,CA,CD_in);

always @ (posedge Clk_reg or posedge Reset)
    if (Reset)
        CD_out  <=0;
    else if (!CSB&&WRB)
        case (CA[7:1])
                7'd00:    CD_out<=Tx_Hwmark                  ;
                7'd01:    CD_out<=Tx_Lwmark                  ; 
                7'd02:    CD_out<=pause_frame_send_en        ; 
                7'd03:    CD_out<=pause_quanta_set           ;
                7'd04:    CD_out<=IFGset                     ; 
                7'd05:    CD_out<=FullDuplex                 ; 
                7'd06:    CD_out<=MaxRetry                   ;
                7'd07:    CD_out<=MAC_tx_add_en              ; 
                7'd08:    CD_out<=MAC_tx_add_prom_data       ;
                7'd09:    CD_out<=MAC_tx_add_prom_add        ; 
                7'd10:    CD_out<=MAC_tx_add_prom_wr         ; 
                7'd11:    CD_out<=tx_pause_en                ; 
                7'd12:    CD_out<=xoff_cpu                   ;
                7'd13:    CD_out<=xon_cpu                    ; 
                7'd14:    CD_out<=MAC_rx_add_chk_en          ; 
                7'd15:    CD_out<=MAC_rx_add_prom_data       ;
                7'd16:    CD_out<=MAC_rx_add_prom_add        ; 
                7'd17:    CD_out<=MAC_rx_add_prom_wr         ; 
                7'd18:    CD_out<=broadcast_filter_en        ; 
                7'd19:    CD_out<=broadcast_bucket_depth     ;    
                7'd20:    CD_out<=broadcast_bucket_interval  ;   
                7'd21:    CD_out<=RX_APPEND_CRC              ; 
                7'd22:    CD_out<=Rx_Hwmark                  ; 
                7'd23:    CD_out<=Rx_Lwmark                  ; 
                7'd24:    CD_out<=CRC_chk_en                 ; 
                7'd25:    CD_out<=RX_IFG_SET                 ; 
                7'd26:    CD_out<=RX_MAX_LENGTH              ; 
                7'd27:    CD_out<=RX_MIN_LENGTH              ; 
                7'd28:    CD_out<=CPU_rd_addr                ; 
                7'd29:    CD_out<=CPU_rd_apply               ;
                7'd30:    CD_out<=CPU_rd_grant               ;
                7'd31:    CD_out<=CPU_rd_dout[15:0]          ; 
                7'd32:    CD_out<=CPU_rd_dout[31:16]         ;                 
                7'd33:    CD_out<=Line_loop_en               ;
                7'd34:    CD_out<=Speed                      ; 
                default:  CD_out<=0                          ;
        endcase
		  
//ADD BY EKADATSKII		  
wire	[ 7:0]		ca_out;
wire	[15:0]		cd_out;
wire					cd_wr;

wire	[ 5:0]		phy_addr;
wire	[ 5:0]		phy_reg_addr;
wire					phy_wr;
wire	[15:0]		phy_dat_out;
wire					phy_wr_start_in;
		  
PhyMacInit PhyMacInit (
	.clk						(		Clk_reg		)
	,.rst_n					(		!Reset		)
	
	,.CA_out					(		ca_out		)
	,.CD_out					(		cd_out		)
	,.CD_wr					(		cd_wr			)
	,.CD_in					(						)
	
	,.phy_rd					(								)
	,.phy_wr					(		phy_wr				)
	,.phy_addr_out			(		phy_addr				)
	,.phy_reg_addr_out	(		phy_reg_addr		)
	,.phy_dat_out			(		phy_dat_out			)
	,.phy_dat_in			(								)
	,.phy_wr_start_in		(		phy_wr_start_in	)

);
assign phy_wr_start_in = WCtrlDataStart;

		  
//PHY ADDRESS
assign Fiad			= phy_addr;
//PHY REG ADDRESS
assign Rgad			= phy_reg_addr;	
//PHY READ OPERATION
assign RStat		= RStat_reg;
//PHY WRITE
assign WCtrlData	= phy_wr;
//PHY WRITE DATA
assign CtrlData	= phy_dat_out;


//TEST BUTTONS
reg btn4_q2;
reg btn4_q1;
reg btn3_q2;
reg btn3_q1;
reg btn2_q2;
reg btn2_q1;
reg btn1_q2;
reg btn1_q1;
always @ (posedge Clk_reg or posedge Reset)
	if(Reset) begin
		btn4_q1		<= 1'b0;
		btn4_q2		<= 1'b0;
		btn3_q1		<= 1'b0;
		btn3_q2		<= 1'b0;
		btn2_q1		<= 1'b0;
		btn2_q2		<= 1'b0;
		btn1_q1		<= 1'b0;
		btn1_q2		<= 1'b0;		
	end
	else begin
		btn4_q1		<= btn4;	
		btn4_q2		<= btn4_q1;
		btn3_q1		<= btn3;	
		btn3_q2		<= btn3_q1;
		btn2_q1		<= btn2;	
		btn2_q2		<= btn2_q1;
		btn1_q1		<= btn1;	
		btn1_q2		<= btn1_q1;
	end

reg RStat_reg;
//READ OPERATION
always @ (posedge Clk_reg or posedge Reset)
	if (Reset)
		RStat_reg	<= 1'b0;
	else if (RStat_reg)
		RStat_reg	<= 1'b0;
	else if (!btn4_q1 & btn4_q2)
		RStat_reg <= 1'b1;

		
/*reg WCtrlData_reg;

reg [15:0] CtrlData_reg;

assign Fiad = 5'b0;
assign Rgad = 5'h17;

//Button regs
		
//READ OPERATION
always @ (posedge Clk_reg or posedge Reset)
	if (Reset)
		RStat_reg	<= 1'b0;
	else if (RStat_reg)
		RStat_reg	<= 1'b0;
	else if (!btn4_q1 & btn4_q2)
		RStat_reg <= 1'b1;
		
//WRITE OPERATION
always @ (posedge Clk_reg or posedge Reset)
	if (Reset)
		WCtrlData_reg	<= 1'b0;
	else if (WCtrlData_reg)
		WCtrlData_reg	<= 1'b0;
	else if (!btn3_q1 & btn3_q2)
		WCtrlData_reg <= 1'b1;
		
//WRITE OPERATION
always @ (posedge Clk_reg or posedge Reset)
	if (Reset)
		CtrlData_reg	<= 16'b0;
	else if (!btn3_q1 & btn3_q2)
		CtrlData_reg	<= 16'b1100_0000_0000_0000;

assign RStat = RStat_reg;
assign WCtrlData = phy_wr;//WCtrlData_reg;
assign CtrlData = phy_dat_out; //16'b1100_0000_0000_0000;//CtrlData_reg;*/


endmodule   

module RegCPUData(
RegOut,   
CA_reg_set, 
RegInit,  
          
Reset,    
Clk,      
CWR_pulse,
CCSB,
CA_reg,     
CD_in_reg
);
output[15:0]    RegOut; 
input[6:0]      CA_reg_set;  
input[15:0]     RegInit;
//
input           Reset;
input           Clk;
input           CWR_pulse;
input           CCSB;
input[7:0]      CA_reg;
input[15:0]     CD_in_reg;
// 
reg[15:0]       RegOut; 


always  @(posedge Reset or posedge Clk)
    if(Reset)
        RegOut      <=RegInit;
    else if (CWR_pulse && !CCSB && CA_reg[7:1] ==CA_reg_set[6:0])  
        RegOut      <=CD_in_reg;
		  
		  
		  

endmodule

//--------------------------------------------------------------------------	
//ADD by EKADATSKII
module PhyMacInit (
	input					clk
	,input				rst_n
	
	//MAC
	,output	[ 7:0]	CA_out			//REG ADDRESS
	,output	[15:0]	CD_out			//DATA OUT
	,output				CD_wr				//DATA WR
	
	,input	[15:0]	CD_in				//DATA IN
	
	//PHY
	,output				phy_rd
	,output				phy_wr
	,output	[ 4:0]	phy_addr_out
	,output	[ 4:0]	phy_reg_addr_out
	,output	[15:0]	phy_dat_out
	,output	[15:0]	phy_dat_in
	,input				phy_wr_start_in
);

localparam		MAC_REG_NUM	= 2;
localparam		PHY_REG_NUM	= 1;
localparam		PHY_ADDR		= 5'b0;

reg	[ 7:0]	wr_cnt_r;
reg				wr_en_r;
reg	[31:0]	phy_timer_r;
reg	[ 7:0]	phy_wr_cnt_r;
reg				phy_wr_en_r;
reg				phy_wr_on_r;
reg				phy_rd_en_r;
reg				phy_wr_start_r;

wire	[ 7:0]	ca_mux;
wire	[15:0]	cd_mux;
wire	[15:0]	phy_reg_addr_mux;
wire	[15:0]	phy_dat_mux;
wire				phy_timer_pas;

//--------------------------------------------------------------------------
//WRITE TO REGISTER ON
always @(posedge clk or negedge rst_n)
	if (!rst_n)												wr_en_r <= 1'b0;
	else if (wr_en_r & (wr_cnt_r == MAC_REG_NUM - 1'b1))
																wr_en_r <= 1'b0;
	else if (wr_cnt_r != MAC_REG_NUM)
																wr_en_r <= 1'b1;	
	
//WRITE TO REGISTER COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)												wr_cnt_r <= 0;
	else if (wr_en_r & (wr_cnt_r != MAC_REG_NUM))		
																wr_cnt_r <= wr_cnt_r + 1'b1;

//WRITE REGISTER ADDRESSES MUX
assign ca_mux =	(wr_cnt_r == 8'h00) ?	8'h00 :			//Tx_Hwmark
						(wr_cnt_r == 8'h01) ?	8'h04 :			//IFGset
														8'h00;
														
//WRITE REGISTER DATA MUX													
assign cd_mux = 	(wr_cnt_r == 8'h00) ?	16'h00FF :		//Tx_Hwmark
						(wr_cnt_r == 8'h01) ?	16'h0012 :		//IFGset
														16'h0000;
//--------------------------------------------------------------------------
//PHY TIMER
always @(posedge clk or negedge rst_n)
	if (!rst_n)												phy_timer_r <= 32'd50_000_000;			//MIN 300ms wait
	else if (!phy_timer_pas)							phy_timer_r <= phy_timer_r - 1'b1;							

//PHY TIMER PAS
assign phy_timer_pas = phy_timer_r == 0;

//PHY WRITE TO REGISTER ON
always @(posedge clk or negedge rst_n)
	if (!rst_n)												phy_wr_en_r <= 1'b0;
	else if (phy_wr_en_r & (phy_wr_cnt_r == PHY_REG_NUM - 1'b1))
																phy_wr_en_r <= 1'b0;
	else if (phy_timer_pas & (phy_wr_cnt_r != PHY_REG_NUM) & !phy_wr_on_r)
																phy_wr_en_r <= 1'b1;	

//PHY WRITE TO REGISTER COUNTER
always @(posedge clk or negedge rst_n)
	if (!rst_n)												phy_wr_cnt_r <= 0;
	else if (phy_wr_start_r & !phy_wr_start_in)		
																phy_wr_cnt_r <= phy_wr_cnt_r + 1'b1;

always @(posedge clk or negedge rst_n)
	if (!rst_n)												phy_wr_start_r <= 0;
	else 														phy_wr_start_r <= phy_wr_start_in;
	
//PHY WRITE PROCESS ON
always @(posedge clk or negedge rst_n)
	if (!rst_n)												phy_wr_on_r <= 1'b0;
	else if (phy_wr_on_r & phy_wr_start_r & !phy_wr_start_in)
																phy_wr_on_r <= 1'b0;
	else if (phy_wr_en_r)
																phy_wr_on_r <= 1'b1;	

																
																
//PHY WRITE REGISTER ADDRESSES MUX
assign phy_reg_addr_mux =	(phy_wr_cnt_r == 8'h00) ?	5'h17 :								//REG 17
																		5'h00;														
														
//PHY WRITE REGISTER DATA MUX													
assign phy_dat_mux		= 	(phy_wr_cnt_r == 8'h00) ?	16'hC000 :		//REG 17
																		16'h0000;														
														
//--------------------------------------------------------------------------		
//MAC OUTPUTS		
assign CA_out	= ca_mux;
assign CD_out	= cd_mux;
assign CD_wr	= wr_en_r;

//PHY OUTPUTS		
assign phy_addr_out		= PHY_ADDR;
assign phy_reg_addr_out = phy_reg_addr_mux;
assign phy_rd				= 1'b0;					//NOT USED
assign phy_wr				= phy_wr_en_r;
assign phy_dat_out		= phy_dat_mux;



endmodule     
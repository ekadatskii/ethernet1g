
module ethernet_1g
(
		input 			clk			//50Mhz clk
		,input			clk_125		//125Mhz clk
		
		//,output			eth_mdc
		//,inout			eth_mdio

		,input				rgmii_rx_clk
		,input	[3:0]		rgmii_rxd
		,input				rgmii_rx_ctl
		
		,output				rgmii_tx_clk
		,output	[3:0]		rgmii_txd
		,output				rgmii_tx_ctl
		
		,output				out_clk
		,output				out_ctl		
		,output				out_clkd0
		,output				out_clkd1
		,output				out_clkd2
		,output				out_clkd3
		
		//MDIO interface
		,inout				Mdio
		,input				Mdint
		,output				Mdc
		
		//Button interfaces
		,input				Btn3
		,input				Btn4
		,input				Btn5
		,input				Btn6		
);

//ALTERA GMII TO RGMII CONVERTER PARAMETERS
parameter TX_PIPELINE_DEPTH = 0;
parameter RX_PIPELINE_DEPTH = 0;
parameter USE_ALTGPIO = 0;

reg [2:0]	rst_rr;

reg [11:0]	rxdat_to_mac;
reg			rxdv_to_mac;

//TEST POS/NEG INPUT REGISTERS
reg 	[3:0] rgmii_pos;
reg	[3:0] rgmii_neg;
reg		 	rgmii_ctl_pos;
reg		 	rgmii_ctl_neg;
reg	[3:0]	rgmii_pos_r;
reg	[3:0]	rgmii_neg_r;
reg			rgmii_ctl_pos_r;
reg			rgmii_ctl_neg_r;

reg			Rx_mac_ra_r;
reg			Rx_mac_eop_r;
reg         Tx_mac_wr_r;




wire [7:0]	rgmii_in_4_temp_reg_out;
wire [1:0]	rgmii_in_1_temp_reg_out;

//FIFO
wire	[9:0]		data_to_fifo;
wire	[9:0]		data_from_fifo;
wire	[7:0]		data_to_mac;
wire				dv_to_mac;
wire				fifo_empty;
wire				fifo_full;

wire				fifo4_wr_full;
wire				fifo4_wr_empty;
wire				fifo4_wr_read;
wire				fifo4_wr_write;
wire	[3:0]		fifo4_wr_data_out;
wire	[3:0]		fifo4_wr_data_in;

wire				fifo32_wr_full;
wire				fifo32_wr_empty;
wire				fifo32_wr_read;
wire				fifo32_wr_write;
wire	[31:0]	fifo32_wr_data_out;
wire	[31:0]	fifo32_wr_data_in;

wire				fifo4_rd_mac_full;
wire				fifo4_rd_mac_empty;
wire				fifo4_rd_mac_read;
wire				fifo4_rd_mac_write;
wire	[3:0]		fifo4_rd_mac_data_out;
wire	[3:0]		fifo4_rd_mac_data_in;

wire				fifo32_rd_mac_full;
wire				fifo32_rd_mac_empty;
wire				fifo32_rd_mac_read;
wire				fifo32_rd_mac_write;
wire	[31:0]	fifo32_rd_mac_data_out;
wire	[31:0]	fifo32_rd_mac_data_in;

//TEST POS/NEG INPUT WIRES
wire [3:0] rgmii_pos_w;
wire [3:0] rgmii_neg_w;
wire		  rgmii_ctl_pos_w;
wire		  rgmii_ctl_neg_w;



//DATA LAYER
wire				dl_up_op_st;
wire				dl_up_op;
wire				dl_up_op_end;
wire	[31:0]	dl_up_data;

wire	[47:0]	dl_source_addr;
wire	[47:0]	dl_dest_addr;
wire	[15:0]	dl_prot_type;

/*
wire	[31:0]	data_layer_rdat;
wire	[1:0]		data_layer_rbe;
wire 				data_layer_rpa;
wire 				data_layer_rsop;
wire 				data_layer_reop;*/

//NETWORK LAYER
wire				nl_up_op_st;
wire				nl_up_op;
wire				nl_up_op_end;
wire	[31:0]	nl_up_data;

wire	[3:0]		nl_version_num;
wire	[3:0]		nl_header_len;
wire	[7:0]		nl_service_type;
wire	[15:0]	nl_total_len;
wire	[15:0]	nl_packet_id;
wire	[2:0]		nl_flags;
wire	[12:0]	nl_frgmt_offset;
wire	[7:0]		nl_ttl;
wire	[7:0]		nl_prot_type;
wire	[15:0]	nl_checksum;
wire	[31:0]	nl_source_addr;
wire	[31:0]	nl_dest_addr;
wire	[15:0]	nl_pseudo_crc;

//Altera Pll signals
wire		pll_25m_clk;
wire		pll_2_5m_clk;
wire		pll_62_5m_clk;

//MDIO Intrface
wire Mdi;
wire Mdo;
wire MdoEn;

//MAC user interface
wire				Rx_mac_ra;
wire	[31:0]	Rx_mac_data;
wire	[1:0]		Rx_mac_BE;
wire				Rx_mac_pa;
wire				Rx_mac_sop;
wire				Rx_mac_eop;

wire           Tx_mac_wa;
wire           Tx_mac_wr;
wire   [31:0]  Tx_mac_data;
wire   [1:0]   Tx_mac_BE;
wire           Tx_mac_sop;
wire           Tx_mac_eop;
wire	 [3:0]	rgmii_out4;
wire	 			rgmii_out1;


//Management signals
//wire		mdo;
//wire		mdoen;
//wire		mdi;
//wire		mdc;

//HPS GMII	 
wire           mac_tx_clk_o;   // hps_gmii								  
wire [7:0]     mac_txd;        // hps_gmii
wire           mac_txen;       // hps_gmii
wire           mac_txer;       // hps_gmii
wire [1:0]     mac_speed;      // hps_gmii
//0x0-0x1: 1000 Mbps(GMII)
//0x2: 10 Mbps (MII)
//0x3: 100 Mbps (MII)

wire          mac_tx_clk_i;   // hps_gmii								
wire          mac_rx_clk;     // hps_gmii
wire          mac_rxdv;       // hps_gmii
wire          mac_rxer;       // hps_gmii
wire [7:0]    mac_rxd;        // hps_gmii
wire          mac_col;        // hps_gmii
wire          mac_crs;        // hps_gmii

wire [3:0]	  alt_adap_txd;
wire 			  alt_adap_txctl;
wire 			  alt_adap_txclk;

wire			  mac_tx_clk_45_shift;

//Output signals
//assign eth_mdc = mdc;
//assign eth_mdio = mdoen ? mdo : 1'b0;

//Input signals
//assign mdi = eth_mdio;

wire				rst_n;
wire				mac_rx_clk_sh;

//RESET
always @(posedge clk)		rst_rr	<= {rst_rr[1:0], 1'b1};
assign rst_n		= rst_rr[2];
	
//--------------------------------------------------------------------------------//
//											ALTERA PLL													 //
//--------------------------------------------------------------------------------//
alt_pll	alt_pll_inst 
(
	.inclk0 ( clk ),
	.c0 ( pll_2_5m_clk ),			//2.5 Mhz
	.c1 ( pll_25m_clk ),				//25  Mhz
	.locked (  )
);

eth_pll eth_pll(
	.inclk0	(mac_tx_clk_o),
	.c0		(mac_tx_clk_45_shift)
);

//ALTERA PLL 125/2
//--------------------------------------------------------
altpll_125	altpll_125_inst
(
	.inclk0 ( clk_125 ),
	.c0 ( pll_62_5m_clk ),			//62.5 Mhz
	.locked (  )
);

//ALTERA PLL 125/2
//--------------------------------------------------------
altpll_125sh	altpll_125sh_inst
(
	.inclk0 ( mac_rx_clk ),
	.c0 ( mac_rx_clk_sh ),			//62.5 Mhz
	.locked (  )
);

//--------------------------------------------------------------------------------//
//									OPENCORES MAC CONTROLLER										 //
//--------------------------------------------------------------------------------//
//OPENCORES 10/100/1000 ETHERNET module
MAC_top MAC_top
(
	.Reset         	(!rst_n)          ,
	.Clk_user         (pll_62_5m_clk) 	,
               //system signals

	.Clk_125M         (clk_125),

	.Clk_reg          (pll_62_5m_clk),
/*
output  [2:0]   Speed                   ,		Speed[2] - gtx(125Mhz), Speed[1] - 25Mhz, Speed[0] - 2.5 Mhz
*/
                //user interface 
.Rx_mac_ra			(Rx_mac_ra),
.Rx_mac_rd			(Rx_mac_ra_r),
.Rx_mac_data		(Rx_mac_data),
.Rx_mac_BE			(Rx_mac_BE),
.Rx_mac_pa			(Rx_mac_pa),
.Rx_mac_sop			(Rx_mac_sop),
.Rx_mac_eop			(Rx_mac_eop),

                //user interface
.Tx_mac_wa			(Tx_mac_wa),
.Tx_mac_wr			(Tx_mac_wr),
.Tx_mac_data		(Tx_mac_data),
.Tx_mac_BE			(Tx_mac_BE),
.Tx_mac_sop			(Tx_mac_sop),
.Tx_mac_eop			(Tx_mac_eop),

/*                //pkg_lgth fifo
input           Pkg_lgth_fifo_rd        ,
output          Pkg_lgth_fifo_ra        ,
output  [15:0]  Pkg_lgth_fifo_data      ,
*/
                //Phy interface          
                //Phy interface 
					 
.Gtx_clk        (mac_tx_clk_o),//used only in GMII mode
.Rx_clk         (mac_rx_clk),
.Tx_clk         (mac_tx_clk_i),//used only in MII mode
.Tx_er          (mac_txer),
.Tx_en          (mac_txen),
.Txd            (mac_txd),
.Rx_er          (1'b0),
.Rx_dv          (dv_to_mac),
.Rxd            (data_to_mac),
.Crs            (1'b0),//(mac_crs),
.Col            (mac_col),


                //host interface
.CSB				(1'b1),
.WRB				(1'b1),
.CD_in			(16'b0),
.CD_out			(),
.CA				(8'b0),
              
                //mdx
.Mdo				(Mdo),               	// MII Management Data Output
.MdoEn			(MdoEn),           		   // MII Management Data Output Enable
.Mdi				(Mdi),
.Mdc				(Mdc),                 	// MII Management Data Clock       

//ADD BY EKADATSKII
.btn1				(Btn3),
.btn2				(Btn4),
.btn3				(Btn5),
.btn4				(Btn6),
.rgmii_pos		(rgmii_pos),
.rgmii_neg		(rgmii_neg),
.rgmii_ctl_pos (rgmii_ctl_pos),
.rgmii_ctl_neg (rgmii_ctl_neg)

);

assign  Mdi=Mdio;
assign  Mdio=MdoEn?Mdo:1'bz;
assign mac_tx_clk_o = clk_125;


//--------------------------------------------------------------------------------//
//									ALTERA GMII-RGMII(mot used 									 //
//--------------------------------------------------------------------------------//
//ALTERA GMII TO RGMII CONVERTER
altera_gmii_to_rgmii_adapter #(TX_PIPELINE_DEPTH, RX_PIPELINE_DEPTH, USE_ALTGPIO) altera_gmii_to_rgmii_adapter	 
(

	//CLOCKS
    .clk					(clk),            // peri_clock
    .rst_n				(rst_n),          // peri_reset

    .pll_25m_clk		(pll_25m_clk),    // pll_25m_clock
    .pll_2_5m_clk		(pll_2_5m_clk),   // pll_2_5m_clock
	 

    .mac_rst_tx_n  	(rst_n),					//????
    .mac_rst_rx_n  	(rst_n),					//????					
	 
	 //HPS GMII	 
	//MAC TXc
    .mac_tx_clk_o		(mac_tx_clk_o),   // hps_gmii								  
    .mac_txd			({mac_txd[3:0], mac_txd[7:4]}),        // hps_gmii
    .mac_txen			(mac_txen),       // hps_gmii
    .mac_txer			(mac_txer),       // hps_gmii
    .mac_speed			(2'b00), 		   // hps_gmii - 10Mbit

	//MAC RX
    .mac_tx_clk_i		(mac_tx_clk_i),   // hps_gmii								
    .mac_rx_clk		(mac_rx_clk),     // hps_gmii
    .mac_rxdv			(mac_rxdv),       // hps_gmii
    .mac_rxer			(mac_rxer),       // hps_gmii
    .mac_rxd			(mac_rxd),        // hps_gmii
    .mac_col			(mac_col),        // hps_gmii
    .mac_crs			(mac_crs),        // hps_gmii

	//PHY RX
	 .rgmii_rx_clk		(rgmii_rx_clk),   // rgmii
    .rgmii_rxd			(rgmii_rxd),      // rgmii
    .rgmii_rx_ctl		(rgmii_rx_ctl),   // rgmii

	//PHY TX
    .rgmii_tx_clk		(alt_adap_txclk),   // rgmii
    .rgmii_txd			(alt_adap_txd),      // rgmii
    .rgmii_tx_ctl		(alt_adap_txctl),   // rgmii
	 
	 .rgmii_in_4_temp_reg_out	(rgmii_in_4_temp_reg_out),
	 .rgmii_in_1_temp_reg_out	(rgmii_in_1_temp_reg_out),
	 
	 .octet_cnt (octet_cnt),
	 .rxdv_to_mac (rxdv_to_mac),
	 .rxdat_to_mac (rxdat_to_mac)
);



//--------------------------------------------------------------------------------//
//										READ DATA PROCESS												 //
//--------------------------------------------------------------------------------//
//RECEIVE DATA FROM TRANSCEIVER
  altera_gtr_rgmii_in4 the_rgmii_in4
    (
      .aclr (),      
      .datain (rgmii_rxd),           
      .dataout_h (rgmii_pos_w),  
      .dataout_l (rgmii_neg_w),  
      .inclock (rgmii_rx_clk)          
    );

//RECEIVE CTL FROM TRANSCEIVER
  altera_gtr_rgmii_in1 the_rgmii_in1
    (
      .aclr (),            
      .datain (rgmii_rx_ctl),      
      .dataout_h (rgmii_ctl_pos_w),
      .dataout_l (rgmii_ctl_neg_w), 
      .inclock (rgmii_rx_clk)             
    );
	 
//DATA & DV FROM RGMII(POS/NEG)
//---------------------------------
always @(posedge rgmii_rx_clk)
	begin
		rgmii_pos			<= rgmii_pos_w;
		rgmii_pos_r			<= rgmii_pos;
	end
always @(posedge rgmii_rx_clk)
	begin
		rgmii_neg			<= rgmii_neg_w;
		rgmii_neg_r 		<= rgmii_neg;
	end
always @(posedge rgmii_rx_clk)
	begin
		rgmii_ctl_pos		<= rgmii_ctl_pos_w;
		rgmii_ctl_pos_r	<= rgmii_ctl_pos;
	end
always @(posedge rgmii_rx_clk)
	begin
		rgmii_ctl_neg		<= rgmii_ctl_neg_w;
		rgmii_ctl_neg_r	<= rgmii_ctl_neg;
	end

//DATA FROM FIFO TO MAC
always @(posedge mac_rx_clk or negedge rst_n)
	if (!rst_n) rxdat_to_mac <= 8'b0;
	else begin
					rxdat_to_mac[11:8] <= rgmii_ctl_neg_r ? rxdat_to_mac[ 3:0] : 4'b0;
					rxdat_to_mac[ 7:4] <= rgmii_ctl_neg_r ? rgmii_neg_r        : 4'b0;
					rxdat_to_mac[ 3:0] <= rgmii_ctl_pos_r ? rgmii_pos_r        : 4'b0;
		  end

//DV REG
always @(posedge mac_rx_clk or negedge rst_n)
	if (!rst_n) rxdv_to_mac <= 1'b0;
	else rxdv_to_mac <= rgmii_ctl_neg_r;	

//DV
assign dv_to_mac = rxdv_to_mac;

//DATA
assign data_to_mac = {rxdat_to_mac[7:4], rxdat_to_mac[11:8]};

//READ FROM MAC OPERATION
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 	Rx_mac_ra_r <= 1'b0;
	else if (Rx_mac_eop & !Rx_mac_eop_r)
						Rx_mac_ra_r <= 1'b0;
	else 				Rx_mac_ra_r <= Rx_mac_ra;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 	Rx_mac_eop_r <= 1'b0;
	else 				Rx_mac_eop_r <= Rx_mac_eop;

//RESYNC FIFO(TRANCEIVER TO MAC)
/*
fifo_resync fifo10_read
(
	.data			(	data_to_fifo	)
	,.rdclk		(	clk_125			)
	,.rdreq		(	!fifo_empty		)// & !rgmii_ctl_neg	)
	,.wrclk		(	rgmii_rx_clk	)
	,.wrreq		(	rxdv_to_mac		)
	,.q			(	data_from_fifo	)
	,.rdempty	(	fifo_empty		)
	,.wrfull		(	fifo_full		)
);

//MAC TO CONTROLLER DATA FIFO
fifo32 fifo32_read_data_mac
(
	.data			(	fifo32_rd_mac_data_in	)
	,.rdclk		(	clk							)
	,.rdreq		(	fifo32_rd_mac_read		)
	,.wrclk		(	clk							)
	,.wrreq		(	fifo32_rd_mac_write		)
	,.q			(	fifo32_rd_mac_data_out	)
	,.rdempty	(	fifo32_rd_mac_empty		)
	,.wrfull		(	fifo32_rd_mac_full		)
);

//MAC TO CONTROLLER CONTROL FIFO
fifo4 fifo4_read_ctl_mac
(
	.data			(	fifo4_rd_mac_data_in		)
	,.rdclk		(	clk							)
	,.rdreq		(	fifo4_rd_mac_read			)
	,.wrclk		(	clk							)
	,.wrreq		(	fifo4_rd_mac_write		)
	,.q			(	fifo4_rd_mac_data_out	)
	,.rdempty	(	fifo4_rd_mac_empty		)
	,.wrfull		(	fifo4_rd_mac_full			)
);


assign fifo32_rd_mac_data_in	= Rx_mac_data;
assign fifo32_rd_mac_write		= Rx_mac_pa;
assign fifo32_rd_mac_read		= !fifo32_rd_mac_empty;

assign fifo4_rd_mac_data_in	= {Rx_mac_BE, Rx_mac_eop, Rx_mac_sop};
assign fifo4_rd_mac_write		= Rx_mac_pa;
assign fifo4_rd_mac_read		= !fifo4_rd_mac_empty;

assign data_layer_rdat	= fifo32_rd_mac_data_out;
assign data_layer_rbe	= fifo4_rd_mac_data_out[3:2];
assign data_layer_rpa	= fifo32_rd_mac_read;
assign data_layer_reop	= fifo4_rd_mac_data_out[1] & data_layer_rpa;
assign data_layer_rsop	= fifo4_rd_mac_data_out[0] & data_layer_rpa;
*/

//READ DATA LINK LAYER(AFTER MAC)
//--------------------------------------------------
data_layer data_layer
(
	.clk					(	pll_62_5m_clk	)
	,.rst_n				(	rst_n				)
	
/*	,.Rx_mac_ra			(	)
	,.Rx_mac_data		(	data_layer_rdat		)
	,.Rx_mac_BE			(	data_layer_rbe			)
	,.Rx_mac_pa			(	data_layer_rpa			)
	,.Rx_mac_sop		(	data_layer_rsop		)
	,.Rx_mac_eop		(	data_layer_reop		)*/
	
	,.Rx_mac_ra			(	)
	,.Rx_mac_data		(	Rx_mac_data		)
	,.Rx_mac_BE			(	Rx_mac_BE		)
	,.Rx_mac_pa			(	Rx_mac_pa		)
	,.Rx_mac_sop		(	Rx_mac_sop		)
	,.Rx_mac_eop		(	Rx_mac_eop		)
	
	,.upper_op_st		(	dl_up_op_st		)
	,.upper_op			(	dl_up_op			)
	,.upper_op_end		(	dl_up_op_end	)
	,.upper_data		(	dl_up_data		)
	
	,.source_addr_o	(	dl_source_addr	)
	,.dest_addr_o		(	dl_dest_addr	)
	,.prot_type_o		(	dl_prot_type	)
);

//READ DATA NETWORK LAYER(IP)
//--------------------------------------------------
network_layer network_layer
(
	.clk					(	pll_62_5m_clk		)
	,.rst_n				(	rst_n					)
	
	,.rcv_op_st			(	dl_up_op_st			)
	,.rcv_op				(	dl_up_op				)
	,.rcv_op_end		(	dl_up_op_end		)
	,.rcv_data			(	dl_up_data			)
	
	,.source_addr_i	(	dl_source_addr		)
	,.dest_addr_i		(	dl_dest_addr		)
	,.prot_type_i		(	dl_prot_type		)
	
	,.upper_op_st		(	nl_up_op_st			)
	,.upper_op			(	nl_up_op				)
	,.upper_op_end		(	nl_up_op_end		)
	,.upper_data		(	nl_up_data			)

	,.version_num_o	(	nl_version_num		)
	,.header_len_o		(	nl_header_len		)
	,.service_type_o	(	nl_service_type	)
	,.total_len_o		(	nl_total_len		)
	,.packet_id_o		(	nl_packet_id		)
	,.flags_o			(	nl_flags				)
	,.frgmt_offset_o	(	nl_frgmt_offset	)
	,.ttl_o				(	nl_ttl				)
	,.prot_type_o		(	nl_prot_type		)
	,.checksum_o		(	nl_checksum			)
	,.source_addr_o	(	nl_source_addr		)
	,.dest_addr_o		(	nl_dest_addr		)
	,.crc_sum_o			()
	,.pseudo_crc_sum_o(	nl_pseudo_crc		)
);

//READ DATA TRANSPORT LAYER(IP)
//--------------------------------------------------
transport_layer transport_layer
(
	.clk					(	pll_62_5m_clk	)
	,.rst_n				(	rst_n				)
	
	,.rcv_op_st			(	nl_up_op_st		)
	,.rcv_op				(	nl_up_op			)
	,.rcv_op_end		(	nl_up_op_end	)
	,.rcv_data			(	nl_up_data		)
	,.prot_type			(	nl_prot_type	)
	,.pseudo_crc_sum	(	nl_pseudo_crc	)
	
	,.source_port_o	()
	,.dest_port_o		()
	,.packet_length_o	()
	,.checksum_o		()
	
	,.upper_op_st		()
	,.upper_op			()
	,.upper_op_end		()
	,.upper_data		()
	,.crc_sum_o			()

);

//--------------------------------------------------------------------------------//
//										WRITE DATA PROCESS											 //
//--------------------------------------------------------------------------------//	 
wire	[31:0]	fifo32_wr_data_mux;
wire	[ 3:0]	fifo4_wr_data_mux;
reg	[15:0]	wr_reg_ptr;
reg				wr_data_en;
wire				wr_data_on;
reg	[15:0]	wr_timer;

//TEST DATA SENDS
assign fifo32_wr_data_mux =	//ETHERNET 2 + IP(lowest 16 bit)
										(wr_reg_ptr == 16'd0)  ? 32'hFFFFFFFF :		
										(wr_reg_ptr == 16'd1)  ? 32'hFFFF04d4 :
										(wr_reg_ptr == 16'd2)  ? 32'hc4a5a8e1 : //32'hc4a5a8e0 :
										(wr_reg_ptr == 16'd3)  ? 32'h08004500 :
										
										//IP + UDP(lowest 16 bit)
										(wr_reg_ptr == 16'd4)  ? 32'h001e64d7 :
										(wr_reg_ptr == 16'd5)  ? 32'h00008011 :
										(wr_reg_ptr == 16'd6)  ? 32'h0000c1e8 :
										(wr_reg_ptr == 16'd7)  ? 32'h1a4fffff :
										(wr_reg_ptr == 16'd8)  ? 32'hfffff718 :
										
										//UDP										
										(wr_reg_ptr == 16'd9)  ? 32'h1388000a :
										(wr_reg_ptr == 16'd10) ? 32'he7cf3132 :
										32'h0000;
	
assign fifo4_wr_data_mux =		//ETHERNET 2
										(wr_reg_ptr == 16'd0)  ? 4'b0001 :
										(wr_reg_ptr == 16'd1)  ? 4'b0000 :
										(wr_reg_ptr == 16'd2)  ? 4'b0000 :
										(wr_reg_ptr == 16'd3)  ? 4'b0000 :
										
										//IP
										(wr_reg_ptr == 16'd4)  ? 4'b0000 :
										(wr_reg_ptr == 16'd5)  ? 4'b0000 :
										(wr_reg_ptr == 16'd6)  ? 4'b0000 :
										(wr_reg_ptr == 16'd7)  ? 4'b0000 :
										(wr_reg_ptr == 16'd8)  ? 4'b0000 :
										
										//UDP	
										(wr_reg_ptr == 16'd9)  ? 4'b0000 :
										(wr_reg_ptr == 16'd10) ? 4'b0010 :
										4'b0000;
										
//TIMER
reg	[31:0]	timer_reg;
wire				timer_pas;

always @(posedge clk_125 or negedge rst_n)
	if (!rst_n)													timer_reg <= 32'd250000000;				//2 sec
	else if (!timer_pas)										timer_reg <= timer_reg - 1'b1;
	
assign timer_pas = timer_reg == 0;
										
//POINTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													wr_reg_ptr <= 16'b0;
	else if ((wr_reg_ptr == 16'd10) & wr_data_on)	wr_reg_ptr <= 16'b0;
	else if (wr_data_on)										wr_reg_ptr <= wr_reg_ptr + 1'b1;

//DATA ENABLE
//always @(posedge pll_62_5m_clk or negedge rst_n)
//	if (!rst_n)												wr_data_en <= 1'b0;
//	else if (!fifo4_wr_full & !fifo32_wr_full)	wr_data_en <= 1'b0;

assign wr_data_on = !fifo4_wr_full & !fifo32_wr_full & timer_pas;
	

assign fifo4_wr_data_in = fifo4_wr_data_mux;
assign fifo32_wr_data_in = fifo32_wr_data_mux;
assign fifo4_wr_write = wr_data_on & !fifo4_wr_full;
assign fifo32_wr_write = wr_data_on & !fifo32_wr_full;

//RESYNC CONTROL WRITE FIFO(CONTROLLER TO MAC)
fifo4 fifo4_write_ctl
(
	.data			(	fifo4_wr_data_in	)
	,.rdclk		(	pll_62_5m_clk		)
	,.rdreq		(	fifo4_wr_read		)
	,.wrclk		(	pll_62_5m_clk		)
	,.wrreq		(	fifo4_wr_write		)
	,.q			(	fifo4_wr_data_out	)
	,.rdempty	(	fifo4_wr_empty		)
	,.wrfull		(	fifo4_wr_full		)
);

//RESYNC DATA WRITE FIFO(CONTROLLER TO MAC)
fifo32 fifo32_write_data
(
	.data			(	fifo32_wr_data_in		)
	,.rdclk		(	pll_62_5m_clk			)
	,.rdreq		(	fifo32_wr_read			)
	,.wrclk		(	pll_62_5m_clk			)
	,.wrreq		(	fifo32_wr_write		)
	,.q			(	fifo32_wr_data_out	)
	,.rdempty	(	fifo32_wr_empty		)
	,.wrfull		(	fifo32_wr_full			)
);

//FIFO TO MAC DATA & CONTROLS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)																Tx_mac_wr_r <= 1'b0;
	else if (!Tx_mac_wa | fifo4_wr_empty | fifo32_wr_empty)	Tx_mac_wr_r <= 1'b0;
	else if (Tx_mac_wa & !fifo4_wr_empty & !fifo32_wr_empty)	Tx_mac_wr_r <= 1'b1;

assign fifo4_wr_read 	= Tx_mac_wr_r & !fifo4_wr_empty  & !fifo32_wr_empty;
assign fifo32_wr_read	= Tx_mac_wr_r & !fifo32_wr_empty & !fifo4_wr_empty;
assign Tx_mac_wr			= Tx_mac_wr_r & !fifo4_wr_empty  & !fifo32_wr_empty;
assign Tx_mac_data		= fifo32_wr_data_out;
assign Tx_mac_BE			= fifo4_wr_data_out[3:2];
assign Tx_mac_eop			= fifo4_wr_data_out[1];
assign Tx_mac_sop			= fifo4_wr_data_out[0];

//-----------------
//MAC LEVEL WORK =)
//-----------------
reg	[7:0]		mac_txd_r;
reg	[7:0]		mac_txd_rr;
reg				mac_txen_r;
reg				mac_txen_rr;

always @(posedge mac_tx_clk_o or negedge rst_n)
	if (!rst_n)		mac_txd_r <= 8'b0;
	else 				mac_txd_r <= mac_txd;
	
always @(posedge mac_tx_clk_o or negedge rst_n)
	if (!rst_n)		mac_txd_rr <= 8'b0;
	else 				mac_txd_rr <= mac_txd_r;
	
always @(posedge mac_tx_clk_o or negedge rst_n)
	if (!rst_n)		mac_txen_r <= 1'b0;
	else 				mac_txen_r <= mac_txen;
	
always @(posedge mac_tx_clk_o or negedge rst_n)
	if (!rst_n)		mac_txen_rr <= 1'b0;
	else 				mac_txen_rr <= mac_txen_r;

	

/*
reg	[7:0]		test_shift;

always @(posedge clk or negedge rst_n)
	if (!rst_n) 					test_shift <= 8'hFF;
	else if (test_shift[0])  	test_shift <= 8'h00;
	else if (!test_shift[0])  	test_shift <= 8'hFF;*/

wire	[3:0]	iobuf_dat_h;
	
  iobuf4_iobuf_in_u5i iobuf4_h
	 ( 
		.datain		(mac_txd_rr[3:0]),
		.dataout		(iobuf_dat_h)
	 );
	 
wire	[3:0]	iobuf_dat_l;
	 
  iobuf4_iobuf_in_u5i iobuf4_l
	 ( 
		.datain		(mac_txd_rr[7:4]),
		.dataout		(iobuf_dat_l)
	 );
	

//SEND DATA FROM MAC TO TRANCEIVER
  altdio_out4 altdio_out4
    (
      .aclr (),
      .datain_h (iobuf_dat_h),
      .datain_l (iobuf_dat_l),
      .outclock (mac_tx_clk_45_shift),
      .dataout  (rgmii_out4)
    );
	 
  altdio_out1 altdio_out1
    (
      .aclr (),
      .datain_h (mac_txen_rr),
      .datain_l (mac_txen_rr),
      .outclock (mac_tx_clk_45_shift),
      .dataout  (rgmii_out1)
    );
	 
	
wire	[3:0]	iobuf_dat_to_phy;

  iobuf4_iobuf_in_u5i iobuf4_to_phy
	 ( 
		.datain		(rgmii_out4),
		.dataout		(iobuf_dat_to_phy)
	 );
	 
wire	iobuf_ctl_to_phy;
	 
  iobuf1_iobuf_in_r5i iobuf1_to_phy
	 ( 
		.datain		(rgmii_out1),
		.dataout		(iobuf_ctl_to_phy)
	 );
	 

/*
//SEND CTL FROM MAC TO TRANCEIVER
  altera_gtr_rgmii_out1 the_rgmii_out1
    (
      .aclr (),
      .datain_h (mac_txer),
      .datain_l (mac_txen),
      .dataout  (rgmii_out1),
      .outclock (mac_tx_clk_o)
    );
*/

//INOUTS
//-------------------------------------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------------------
assign rgmii_tx_clk = mac_tx_clk_o;
assign rgmii_txd = iobuf_dat_to_phy;
assign rgmii_tx_ctl = iobuf_ctl_to_phy;

//TEST PINS	
/*
//INPUTS	
assign out_clk = rgmii_rx_clk;
assign out_ctl = rgmii_rx_ctl;
assign out_clkd0 = rgmii_rxd[0];
assign out_clkd1 = rgmii_rxd[1];
assign out_clkd2 = rgmii_rxd[2];
assign out_clkd3 = rgmii_rxd[3];
*/

//OUTPUTS
//USER OUT
/*
assign out_clk = mac_tx_clk_o;
assign out_ctl = rgmii_out1;
assign out_clkd0 = rgmii_out4[0];
assign out_clkd1 = rgmii_out4[1];
assign out_clkd2 = rgmii_out4[2];
assign out_clkd3 = rgmii_out4[3];*/


//ADAPTER OUT
/*
assign out_clk = alt_adap_txclk;
assign out_ctl = alt_adap_txctl;
assign out_clkd0 = alt_adap_txd[0];
assign out_clkd1 = alt_adap_txd[1];
assign out_clkd2 = alt_adap_txd[2];
assign out_clkd3 = alt_adap_txd[3];
*/
endmodule

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
	
		//LEDS
		,output				User_led1		
		,output				User_led2
		,output				User_led3	
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

wire			  mac_tx_clk_45_shift;


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
wire	[15:0]	nl_up_data_len;

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

wire	[3:0]	iobuf_dat_h;
wire	[3:0]	iobuf_dat_l;
wire	[3:0]	iobuf_dat_to_phy;
wire			iobuf_ctl_to_phy;


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
/*
alt_pll	alt_pll_inst 
(
	.inclk0 ( clk ),
	.c0 ( pll_2_5m_clk ),			//2.5 Mhz
	.c1 ( pll_25m_clk ),				//25  Mhz
	.locked (  )
);*/
/*
eth_pll eth_pll(
	.inclk0	(mac_tx_clk_o),
	.c0		(mac_tx_clk_45_shift)
);*/
wire pll_250_clk;
//ALTERA PLL 125/2
//--------------------------------------------------------
altpll_125	altpll_125_inst
(
	.inclk0 ( clk_125 ),
	.c0 ( pll_62_5m_clk ),			//62.5 Mhz
	.c1 ( mac_tx_clk_45_shift ),
//	.c2 ( pll_250_clk ),				//62.5 Mhz
	.locked (  )
);

//ALTERA PLL 125/2
//--------------------------------------------------------
/*
altpll_125sh	altpll_125sh_inst
(
	.inclk0 ( mac_rx_clk ),
	.c0 ( mac_rx_clk_sh ),			//62.5 Mhz
	.locked (  )
);*/

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
//assign mac_tx_clk_o = clk_125;


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
	else 				Rx_mac_eop_r <= Rx_mac_eop & Rx_mac_ra;

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
	,.upper_data_len	(	nl_up_data_len		)

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
	,.rcv_data_len		(	nl_up_data_len	)
	,.prot_type			(	nl_prot_type	)
	,.pseudo_crc_sum	(	nl_pseudo_crc	)
	
	,.source_port_o	(	tcp_source_port_i	)
	,.dest_port_o		()
	,.packet_length_o	()
	,.checksum_o		()
	,.seq_num_o			(	tcp_seq_num_i		)
	,.ack_num_o			(	tcp_ack_num_i		)
	,.tcp_flags_o		(	tcp_flags_i			)
	,.options_o			(	tcp_options_i		)
	,.tcp_head_len_o	(	tcp_head_len_i		)
	,.tcp_window_o		(	tcp_window_i		)
	
	,.upper_op_st		(	udp_upper_op_st	)
	,.upper_op			(	udp_upper_op		)
	,.upper_op_end		(	udp_upper_op_end	)
	,.upper_data		(	udp_upper_data		)
	,.crc_sum_o			(	udp_crc_sum			)

);

wire	[95:0]	tcp_options_i;

wire 				udp_upper_op_st;
wire 				udp_upper_op;
wire 				udp_upper_op_end;
wire	[31:0]	udp_upper_data;
wire 	[15:0]	udp_crc_sum;

reg	[15:0]	increment_cnt;
reg	[15:0]	increment_data;
reg	[7:0]		udp_data_cnt;
reg				increment_err;
reg				crc_err;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)							udp_data_cnt <= 8'b0;
	else if (udp_upper_op_end)		udp_data_cnt <= 8'b0;
	else if (udp_upper_op & (udp_data_cnt < 4))			
											udp_data_cnt <= udp_data_cnt + 1'b1;
					
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)							increment_data <= 16'b0;
	else if (udp_data_cnt == 8'd3)increment_data <= udp_upper_data[31:16];	


always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 						increment_cnt <= 16'b0;
	else if (udp_upper_op_end)		increment_cnt <= increment_cnt + 1'b1;
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 																	increment_err <= 1'b0;
	else if (udp_upper_op_end & (increment_data != increment_cnt))	increment_err <= 1'b1;
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 																	crc_err <= 1'b0;
	else if (udp_upper_op_end & (udp_crc_sum != 16'hFFFF))			crc_err <= 1'b1;

reg [31:0] 	led_timer;
reg			led_on;
wire			led_timer_pas;
	
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													led_timer <= 32'd125_000_000;				//2
	else if (udp_upper_op)									led_timer <= 32'd125_000_000;				//2
	else if (!led_timer_pas)								led_timer <= led_timer - 1'b1;
	
assign led_timer_pas = led_timer == 0;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)						led_on <= 1'b0;			//OFF
	else if (udp_upper_op)		led_on <= 1'b1;
	else if (led_timer_pas)		led_on <= 1'b0;
	
assign User_led1 = !led_on;	
assign User_led2 = !increment_err;
assign User_led3 = !crc_err;

//--------------------------------------------------------------------------------//
//FIFO for control signals collection
//
wire	[101:0] ctrl_fifo_i = {tcp_data_len_i[15:0], tcp_flags_i[5:0], tcp_window_i[15:0], tcp_seq_num_i[31:0], tcp_ack_num_i[31:0]};

umio_fifo #(16, 102) fifo_ctrl
(
	.rst_n					(	rst_n					)
	,.clk						(	pll_62_5m_clk		)
	,.rd_data				(	ctrl_fifo_o			)
	,.wr_data				(	ctrl_fifo_i			)
	,.rd_en					(	tcp_op_rcv_rd_o	)
	,.wr_en					(	nl_up_op_end & !fifo_ctrl_full )
	,.full					(	fifo_ctrl_full		)
	,.empty					(	fifo_ctrl_empty	)
);

wire	[101:0]		ctrl_fifo_o;
wire	[15:0]		tcp_data_len_ii	= ctrl_fifo_o[101:86]; 
wire	[ 5:0]		tcp_flags_ii		= ctrl_fifo_o[85:80];
wire	[15:0]		tcp_window_ii		= ctrl_fifo_o[79:64];
wire	[31:0]		tcp_seq_num_ii		= ctrl_fifo_o[63:32];
wire	[31:0]		tcp_ack_num_ii 	= ctrl_fifo_o[31:0];

wire					tcp_op_rcv_rd_o;
wire					fifo_ctrl_full;
wire					fifo_ctrl_empty;
wire					packet_drop;

reg	[31:0]		packet_next;


//NEXT RECEIVE PACKET NUMBER
always @(posedge clk or negedge rst_n)
	if (!rst_n)												packet_next <= 0;
	else if (nl_up_op_end & tcp_flags_i[1])	//SYN
																packet_next <= tcp_seq_num_i + tcp_data_len_i;
	else if (nl_up_op_end & tcp_flags_i[4] & (tcp_seq_num_i == packet_next))	//ACK
																packet_next <= tcp_seq_num_i + tcp_data_len_i;
																
assign packet_drop = (nl_up_op_end & tcp_flags_i[4] & (tcp_seq_num_i != packet_next));
//--------------------------------------------------------------------------------//
//										TCP CONTROLLER													 //
//--------------------------------------------------------------------------------//
tcp_controller	tcp_controller
(
	.clk						(	pll_62_5m_clk	)
	,.rst_n					(	rst_n				)
	
	,.tcp_op_rcv_i			(	!fifo_ctrl_empty	)
	,.tcp_source_port_i	(	tcp_source_port_i	)
	,.tcp_dest_port_i		(	tcp_dest_port_i	)	
	,.tcp_flags_i			(	tcp_flags_ii		)
	,.tcp_seq_num_i		(	tcp_seq_num_ii		)
	,.tcp_ack_num_i		(	tcp_ack_num_ii		)
	,.tcp_options_i		(							)
	,.tcp_data_len_i		(	tcp_data_len_ii	)
	,.tcp_window_i			(	tcp_window_ii		)
	,.tcp_op_rcv_rd_o		(	tcp_op_rcv_rd_o	)

	,.tcp_source_port_o	(	tcp_source_port_o	)
	,.tcp_dest_port_o		(	tcp_dest_port_o	)
	,.tcp_flags_o			(	tcp_flags_o			)
	,.tcp_seq_num_o		(	tcp_seq_num_o		)
	,.tcp_ack_num_o		(	tcp_ack_num_o		)
	,.tcp_head_len_o		(	tcp_head_len_o		)
	,.tcp_start_o			(	tcp_start_o			)
	,.tcp_data_len_o		(	tcp_data_len_o		)
	,.tcp_write_op_end_i	(							)
	,.wdat_start_o			(	wdat_start_o		)
	,.wdat_stop_i			(	udp_eop				)
	,.trnsmt_busy_i		(	tcp_controller_busy	)
	,.ram_lock_all_i		(	ram_lock_all		)
	,.ram_lock_any_i		(	ram_lock_any		)
	,.old_data_start_o	(	old_data_start_o	)
	,.tcp_state_listen_o	(	tcp_ctrl_state_idle)
	,.tcp_state_estblsh_o(	tcp_state_estblsh_o)
	,.old_data_en_o		(	old_data_en_o		)
	
	,.ram_seq_lock_00		(	ram_seq_lock_00	)
	,.ram_seq_lock_01		(	ram_seq_lock_01	)
	,.ram_seq_lock_02		(	ram_seq_lock_02	)
	,.ram_seq_lock_03		(	ram_seq_lock_03	)
	,.ram_seq_lock_04		(	ram_seq_lock_04	)
	,.ram_seq_lock_05		(	ram_seq_lock_05	)
	,.ram_seq_lock_06		(	ram_seq_lock_06	)
	,.ram_seq_lock_07		(	ram_seq_lock_07	)
	,.ram_seq_num_r_00	(	ram_seq_num_r_00	)
	,.ram_seq_num_r_01	(	ram_seq_num_r_01	)
	,.ram_seq_num_r_02	(	ram_seq_num_r_02	)
	,.ram_seq_num_r_03	(	ram_seq_num_r_03	)
	,.ram_seq_num_r_04	(	ram_seq_num_r_04	)
	,.ram_seq_num_r_05	(	ram_seq_num_r_05	)
	,.ram_seq_num_r_06	(	ram_seq_num_r_06	)
	,.ram_seq_num_r_07	(	ram_seq_num_r_07	)
	,.ram_lock				(	ram_lock				)
	
	
);

assign tcp_data_len_i = nl_up_data_len - (tcp_head_len_i*4); 

//--------------------------------------------------------------------------------//
//										WRITE DATA PROCESS											 //
//--------------------------------------------------------------------------------//
parameter UDP_DATA_LENGTH_IN_BYTE = 16'd00;//16'd1450;

wire	[47:0]		mac_dst_addr		= 48'h04_D4_C4_A5_A8_E0;//DENIS//48'h04_D4_C4_A5_93_CB;
wire	[47:0]		mac_src_addr		= 48'h04_D4_C4_A5_A8_E1;
wire	[15:0]		mac_type				= 16'h08_00;

wire	[ 3:0]		ip_version			= 4'h4;
wire	[ 3:0]		ip_head_len			= 4'h5;
wire	[ 7:0]		ip_dsf				= 8'h00;
wire	[15:0]		ip_total_len		= 16'd20/*ip length*/ + (tcp_head_len_o*16'd4)/*udp header length*/ + tcp_data_len_o;
wire	[15:0]		ip_id					= 16'h64_D7;		//25815
wire	[ 2:0]		ip_flag				= 3'h0;
wire	[13:0]		ip_frag_offset		= 13'h00_00;		
wire	[ 7:0]		ip_ttl				= 8'h80;				//128
wire	[ 7:0]		ip_prot				= 8'h06;				//TCP
//wire	[15:0]		ip_head_chksum		= 16'h00_00;
wire	[31:0]		ip_src_addr			= 32'hC1_E8_1A_4E; //193.232.26.78 //= 32'hA9_FE_CE_77;		//169.254.206.119
//wire	[31:0]		ip_src_addr			= 32'hFF_FF_FF_FF;
wire	[31:0]		ip_dst_addr			= 32'hC1_E8_1A_4F;//DENIS//32'hC1_E8_1A_64;
wire	[31:0]		ip_options			= 32'h00_00_00_00;		//Not used now
	
wire	[15:0]		udp_src_port		= 16'hF718;			//63256
wire	[15:0]		udp_dst_port		= 16'h1EA5;			//16'h1389;			//5001	
wire	[15:0]		tcp_source_port_i;
wire	[15:0]		tcp_source_port_o;
wire	[15:0]		tcp_dest_port_i;
wire	[15:0]		tcp_dest_port_o;
wire	[31:0]		tcp_seq_num_i;
wire	[31:0]		tcp_ack_num_i;
wire	[31:0]		tcp_seq_num_o;
wire	[31:0]		tcp_ack_num_o;
wire	[15:0]		tcp_data_len_i; 
wire	[ 3:0]		tcp_head_len_i;
wire	[ 3:0]		tcp_head_len_o;
wire					old_data_en_o;

wire	[31:0]		tcp_seq_num			= 32'h0000_0001;
wire	[31:0]		tcp_ack_num			= tcp_seq_num_i + 1'b1;//32'h0000_0000;
wire	[ 3:0]		tcp_head_len		= 4'h8;
wire	[ 5:0]		tcp_flags			= 6'h012;
wire	[ 5:0]		tcp_flags_i;
wire	[ 5:0]		tcp_flags_o;
wire					tcp_start_o;
wire	[15:0]		tcp_window			= 16'd40000;						//TODO change size
wire	[15:0]		tcp_urgent_ptr		= 16'h0000;
wire	[95:0]		tcp_options			= 96'h020405b4_01_030308_01_01_0402;
wire	[15:0]		udp_data_length	= UDP_DATA_LENGTH_IN_BYTE;
wire	[15:0]		tcp_data_len_o;
wire					wdat_start_o;
wire	[15:0]		tcp_window_i;
wire					old_data_start_o;

wire	[31:0]		udp_data_tr			= 32'h00_01_02_03;

wire	[31:0]		usb_prot_head0		= 32'h5E4D0B05;
wire	[15:0]		usb_prot_head1		= 32'h9FB4;
wire					tcp_ctrl_state_idle;
wire					tcp_state_estblsh_o;

//OUTPUTS
wire	[31:0]		udp_data_o;
wire	[1:0]			udp_be_o;
wire 					udp_data_rdy_o;
wire					udp_data_in_rd;
wire					udp_sop;
wire					udp_eop;

//INPUT FROM FIFO
wire					udp_data_out_rd;

reg				start_reg;
reg				start_lock;
reg				udp_run;
reg				udp_start;
reg				udp_start_lock;
reg	[31:0]	udp_data_gen;
reg	[63:0]	udp_packet_num;
reg	[ 3:0]	udp_content_chkr;

wire				udp_fifo_data_wr;
reg	[15:0]	udp_fifo_data_wr_chkr;
wire	[31:0]	udp_fifo_rdata;

wire	[31:0]	udp_data_chksum_w;
wire	[31:0]	udp_data_chksum_ww;
wire	[31:0]	udp_data_chksum_www;
wire	[15:0]	udp_data_chksum;
reg	[15:0]	udp_data_chksum_r;

wire				transmitter_work;

//START AFTER WAIT
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									start_reg <= 1'b0;
	else if (start_reg)							start_reg <= 1'b0;
	else if (wdat_start_o & !start_lock)	start_reg <= 1'b1;
	
//START LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									start_lock <= 1'b0;
	else if (udp_eop)								start_lock <= 1'b0;
	else if (wdat_start_o)						start_lock <= 1'b1;
	
//RUN DATA SEND TO FIFO
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									udp_run <= 1'b0;
	else if (udp_eop)								udp_run <= 1'b0;
	else if (start_reg)							udp_run <= 1'b1;
	
assign udp_fifo_data_wr = udp_run & (udp_fifo_data_wr_chkr < tcp_data_len_o);

//UDP DATA SEND TO FIFO COUNTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									udp_fifo_data_wr_chkr <= 16'b0;
	else if (udp_eop)								udp_fifo_data_wr_chkr <= 16'b0;
	else if (udp_fifo_data_wr)					udp_fifo_data_wr_chkr <= udp_fifo_data_wr_chkr + 4'd4;
	
//START SEND DATA FROM FIFO TO UDP TRANSMITTER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									udp_start <= 1'b0;
	else if (udp_start)							udp_start <= 1'b0;
	else if ((udp_fifo_data_wr_chkr >= tcp_data_len_o) & !udp_start_lock & udp_run)
														udp_start <= 1'b1;	
//START LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 									udp_start_lock <= 1'b0;
	else if (udp_eop)								udp_start_lock <= 1'b0;
	else if ((udp_fifo_data_wr_chkr >= tcp_data_len_o) & udp_run)
														udp_start_lock <= 1'b1;

//UDP PACKET NUMBER OR UDP DATA SELECTOR
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					udp_content_chkr <= 4'd4;
	else if (udp_eop & udp_data_out_rd)
					udp_content_chkr <= 4'd4;
	else if (udp_fifo_data_wr & (udp_content_chkr != 4'd2))
					udp_content_chkr <= udp_content_chkr - 1'b1;	
				
reg	[7:0]		usb_crc8_reg;
wire	[7:0]		usb_crc8_w1;
wire	[7:0]		usb_crc8_w2;
				
// CRC8 DATA
crc8_ftdi crc8_data_high
(
	.data_i		(	udp_packet_num[15:8]	),
	.crc_i		(	8'h1B						),
	.crc_o		(	usb_crc8_w1				)
);	

crc8_ftdi crc8_data_low
(
	.data_i		(	udp_packet_num[7:0]	),
	.crc_i		(	usb_crc8_w1				),
	.crc_o		(	usb_crc8_w2				)
);

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)					usb_crc8_reg <= 8'h00;
	else if (start_reg)		usb_crc8_reg <= 8'hC6;//usb_crc8_w2;
				

//UDP DATA GENERATOR				
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
					udp_data_gen <= udp_packet_num;
	else if (start_reg)
					udp_data_gen <= usb_prot_head0;//udp_packet_num[63:32];
	else if ((udp_content_chkr == 4'd4) & udp_fifo_data_wr)
					udp_data_gen <= {usb_prot_head1, udp_packet_num[15:0]};//udp_packet_num[31: 0];
	else if ((udp_content_chkr == 4'd3) & udp_fifo_data_wr)
					udp_data_gen <= udp_data_tr;	
	else if ((udp_content_chkr == 4'd2) & udp_fifo_data_wr & (udp_fifo_data_wr_chkr == 16'd1440))
				begin
					udp_data_gen[31:24] <= udp_data_gen[31:24] + 4'd4;
					udp_data_gen[23:16] <= udp_data_gen[23:16] + 4'd4;//usb_crc8_reg;//8'h00;//8'hDD;
					udp_data_gen[15: 8] <= 8'h00;
					udp_data_gen[ 7: 0] <= 8'h00;
				end	
	
	else if ((udp_content_chkr == 4'd2) & udp_fifo_data_wr)	
				begin
					udp_data_gen[31:24] <= udp_data_gen[31:24] + 4'd4;
					udp_data_gen[23:16] <= udp_data_gen[23:16] + 4'd4;
					udp_data_gen[15: 8] <= udp_data_gen[15: 8] + 4'd4;
					udp_data_gen[ 7: 0] <= udp_data_gen[ 7: 0] + 4'd4;
				end

//UDP PACKET NUMBER
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					udp_packet_num <= 64'b0;
	else if (udp_eop & udp_data_out_rd & udp_run)
					udp_packet_num <= udp_packet_num + 1'b1;	
					
//UDP DATA CRC
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)							udp_data_chksum_r <= 16'b0;
//	else if (udp_eop)					udp_data_chksum_r <= 16'b0;
	else if (start_reg | tcp_start_o)
											udp_data_chksum_r <= 16'b0;
	else if (udp_fifo_data_wr)		udp_data_chksum_r <= udp_data_chksum;
	else if (old_data_start_o)		udp_data_chksum_r <= ram_data_chksum;
	
assign udp_data_chksum_w =	(udp_fifo_data_wr_chkr + 4'd1 == tcp_data_len_o) ? {udp_data_gen[31:24], 8'h00} : 
									(udp_fifo_data_wr_chkr + 4'd2 == tcp_data_len_o) ?  udp_data_gen[31:16] : 
									(udp_fifo_data_wr_chkr + 4'd3 == tcp_data_len_o) ? (udp_data_gen[31:16] + {udp_data_gen[15:8], 8'h00}) : (udp_data_gen[31:16] + udp_data_gen[15:0]);
									
assign udp_data_chksum_ww	= udp_data_chksum_w + udp_data_chksum_r[15:0];
assign udp_data_chksum_www	= udp_data_chksum_ww[31:16] + udp_data_chksum_ww[15:0];
assign udp_data_chksum		= udp_data_chksum_www[31:16] + udp_data_chksum_www[15:0];	//= udp_data_chksum_ww[31:16] + udp_data_chksum_ww[15:0]; TODO for resend test

//RAM TO COLLECT UDP DATA	
//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
localparam RAM_NUMBER = 8;

reg	[5:0]					ram_cnt;
wire	[5:0]					ram_prev_unconf;
wire							ram_lock_all;
wire							ram_lock_any;
wire	[15:0]				ram_lock_list;
wire	[RAM_NUMBER-1:0]	ram_lock;
wire	[RAM_NUMBER-1:0]	ram_sel;
wire	[15:0]				ram_data_chksum;
reg							ram_lock_stop;
reg							old_data_start;
wire							ram_lock_mux;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n) 							old_data_start <= 1'b0;
	else if (old_data_start)			old_data_start <= 1'b0;
	else if (old_data_start_o)			old_data_start <= 1'b1;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)								ram_cnt <= 0;
	else if (udp_run & udp_eop & (ram_cnt == RAM_NUMBER - 1))
												ram_cnt <= 0;
	else if (udp_run & udp_eop)		ram_cnt <= ram_cnt + 1'b1;
	else if (tcp_ctrl_state_idle)		ram_cnt <= ram_prev_unconf;			//TODO JUST FOR TEST
	else if (old_data_en_o & !old_data_start_o & !old_data_start & !tcp_controller_busy & tcp_state_estblsh_o & !ram_lock_mux)
												ram_cnt <= ram_cnt + 1'b1;
												
assign ram_lock_mux =	(ram_cnt == 6'd0) ? ram_lock[0] : 
								(ram_cnt == 6'd1) ? ram_lock[1] : 
								(ram_cnt == 6'd2) ? ram_lock[2] : 
								(ram_cnt == 6'd3) ? ram_lock[3] : 
								(ram_cnt == 6'd4) ? ram_lock[4] : 
								(ram_cnt == 6'd5) ? ram_lock[5] : 
								(ram_cnt == 6'd6) ? ram_lock[6] : 
								(ram_cnt == 6'd7) ? ram_lock[7] : 
								1'b0;			
	
device_arbiter #(RAM_NUMBER) unconfirmed_data_arb
(
	.clk						(pll_62_5m_clk)
	,.rst_n					(rst_n)
	
	//Connection with end controller
	,.wr_allow				(1'b1)
	
	//Connection with controllers
	
	,.dev_rdy				(ram_lock_list)	
	,.sel						(ram_sel)		
	
	,.port_number			(ram_prev_unconf)
	
	
	//Connection with encoder
	,.start					()
	,.stop					(ram_lock_stop)
);											


assign ram_lock = {ram_lock_r_07, ram_lock_r_06, ram_lock_r_05, ram_lock_r_04, ram_lock_r_03, ram_lock_r_02, ram_lock_r_01, ram_lock_r_00}; //
assign udp_fifo_rdata = (ram_cnt == 6'd0) ? ram_rdata_00 :
								(ram_cnt == 6'd1) ? ram_rdata_01 :
								(ram_cnt == 6'd2) ? ram_rdata_02 :
								(ram_cnt == 6'd3) ? ram_rdata_03 :
								(ram_cnt == 6'd4) ? ram_rdata_04 :
								(ram_cnt == 6'd5) ? ram_rdata_05 :
								(ram_cnt == 6'd6) ? ram_rdata_06 :
								(ram_cnt == 6'd7) ? ram_rdata_07 : 32'b0; 
								
assign ram_data_chksum =(ram_cnt == 6'd0) ? ram_data_chksum_00 :
								(ram_cnt == 6'd1) ? ram_data_chksum_01 :
								(ram_cnt == 6'd2) ? ram_data_chksum_02 :
								(ram_cnt == 6'd3) ? ram_data_chksum_03 :
								(ram_cnt == 6'd4) ? ram_data_chksum_04 :
								(ram_cnt == 6'd5) ? ram_data_chksum_05 :
								(ram_cnt == 6'd6) ? ram_data_chksum_06 :
								(ram_cnt == 6'd7) ? ram_data_chksum_07 : 32'b0;
assign ram_lock_all = ram_lock_r_00 & ram_lock_r_01 & ram_lock_r_02 & ram_lock_r_03 & ram_lock_r_04 & ram_lock_r_05 & ram_lock_r_06 & ram_lock_r_07; //: TODO ALL. USE &
assign ram_lock_any = ram_lock_r_00 | ram_lock_r_01 | ram_lock_r_02 | ram_lock_r_03 | ram_lock_r_04 | ram_lock_r_05 | ram_lock_r_06 | ram_lock_r_07; //| 
assign ram_lock_list = {ram_lock_r_07, ram_lock_r_06, ram_lock_r_05, ram_lock_r_04, ram_lock_r_03, ram_lock_r_02, ram_lock_r_01, ram_lock_r_00};


//IRQ selected flag		
integer n;
always @(posedge clk or negedge rst_n)
  if (!rst_n)			
					ram_lock_stop	<= 1'b0;
  else if (ram_lock_stop) 
					ram_lock_stop <= 1'b0;	
				
  else if (|ram_sel & !ram_lock_stop)
    for (n = 0; n < RAM_NUMBER; n = n + 1)
      if (ram_sel[n] & !ram_lock_list[n])
					ram_lock_stop <= 1'b1;
//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_00;
reg	[ 8:0]	ram_data_rd_addr_r_00;
reg	[31:0]	ram_seq_num_r_00;
reg				ram_lock_r_00;
reg				ram_seq_lock_00;
reg	[15:0]	ram_data_chksum_00;
wire	[ 8:0]	ram_data_rd_addr_00;
wire				ram_data_wr_00;
wire	[31:0]	ram_rdata_00;

ram2048	ram_data_00 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_00	)
	,.wraddress				( ram_data_wr_addr_r_00	)
	,.wren					( ram_data_wr_00			)
	,.q						( ram_rdata_00				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_00 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_00 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_00 <= ram_data_wr_addr_r_00 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_00 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_00 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_00 <= ram_data_rd_addr_r_00 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_00 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_00)) & (ram_cnt == 6'd0))
						ram_seq_num_r_00 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_00 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_00 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_00 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd0))
						ram_seq_lock_00 <= 1'b1;


//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_00 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_00 + 16'd1450) <= tcp_ack_num_i) & !old_data_en_o)
						ram_lock_r_00 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_00 + 16'd1450) <= tcp_ack_num_i) & old_data_en_o & (ram_cnt == 6'd0))
						ram_lock_r_00 <= 0;
	else if (start_reg & (ram_cnt == 6'd0))
						ram_lock_r_00 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_00 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd0))
						ram_data_chksum_00 <= udp_data_chksum;

						
assign ram_data_rd_addr_00 = ram_data_rd_addr_r_00 + udp_data_in_rd;
assign ram_data_wr_00 = udp_fifo_data_wr & (ram_cnt == 6'd0);


//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_01;
reg	[ 8:0]	ram_data_rd_addr_r_01;
reg	[31:0]	ram_seq_num_r_01;
reg				ram_lock_r_01;
reg				ram_seq_lock_01;
reg	[15:0]	ram_data_chksum_01;
wire	[ 8:0]	ram_data_rd_addr_01;
wire				ram_data_wr_01;
wire	[31:0]	ram_rdata_01;

ram2048	ram_data_01 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_01	)
	,.wraddress				( ram_data_wr_addr_r_01	)
	,.wren					( ram_data_wr_01			)
	,.q						( ram_rdata_01				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_01 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_01 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_01 <= ram_data_wr_addr_r_01 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_01 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_01 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_01 <= ram_data_rd_addr_r_01 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_01 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_01)) & (ram_cnt == 6'd1))
						ram_seq_num_r_01 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_01 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_01 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_01 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd1))
						ram_seq_lock_01 <= 1'b1;

//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_01 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_01 + 16'd1450) <= tcp_ack_num_i) & !old_data_en_o)
						ram_lock_r_01 <= 0;						
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_01 + 16'd1450) <= tcp_ack_num_i) & old_data_en_o & (ram_cnt == 6'd1))
						ram_lock_r_01 <= 0;
	else if (start_reg & (ram_cnt == 6'd1))
						ram_lock_r_01 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_01 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd1))
						ram_data_chksum_01 <= udp_data_chksum;					

						
assign ram_data_rd_addr_01 = ram_data_rd_addr_r_01 + udp_data_in_rd;
assign ram_data_wr_01 = udp_fifo_data_wr & (ram_cnt == 6'd1);

//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_02;
reg	[ 8:0]	ram_data_rd_addr_r_02;
reg	[31:0]	ram_seq_num_r_02;
reg	[15:0]	ram_data_chksum_02;
reg				ram_lock_r_02;
reg				ram_seq_lock_02;
wire	[ 8:0]	ram_data_rd_addr_02;
wire				ram_data_wr_02;
wire	[31:0]	ram_rdata_02;

ram2048	ram_data_02 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_02	)
	,.wraddress				( ram_data_wr_addr_r_02	)
	,.wren					( ram_data_wr_02			)
	,.q						( ram_rdata_02				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_02 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_02 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_02 <= ram_data_wr_addr_r_02 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_02 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_02 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_02 <= ram_data_rd_addr_r_02 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_02 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_02)) & (ram_cnt == 6'd2))
						ram_seq_num_r_02 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_02 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_02 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_02 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd2))
						ram_seq_lock_02 <= 1'b1;
						
//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_02 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_02 + 16'd1450) <= tcp_ack_num_i) & !old_data_en_o)
						ram_lock_r_02 <= 0;						
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_02 + 16'd1450) <= tcp_ack_num_i) & old_data_en_o & (ram_cnt == 6'd2))
						ram_lock_r_02 <= 0;
	else if (start_reg & (ram_cnt == 6'd2))
						ram_lock_r_02 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_02 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd2))
						ram_data_chksum_02 <= udp_data_chksum;

						
assign ram_data_rd_addr_02 = ram_data_rd_addr_r_02 + udp_data_in_rd;
assign ram_data_wr_02 = udp_fifo_data_wr & (ram_cnt == 6'd2);

//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_03;
reg	[ 8:0]	ram_data_rd_addr_r_03;
reg	[31:0]	ram_seq_num_r_03;
reg	[15:0]	ram_data_chksum_03;
reg				ram_lock_r_03;
reg				ram_seq_lock_03;
wire	[ 8:0]	ram_data_rd_addr_03;
wire				ram_data_wr_03;
wire	[31:0]	ram_rdata_03;

ram2048	ram_data_03 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_03	)
	,.wraddress				( ram_data_wr_addr_r_03	)
	,.wren					( ram_data_wr_03			)
	,.q						( ram_rdata_03				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_03 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_03 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_03 <= ram_data_wr_addr_r_03 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_03 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_03 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_03 <= ram_data_rd_addr_r_03 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_03 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_03)) & (ram_cnt == 6'd3))
						ram_seq_num_r_03 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_03 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_03 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_03 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd3))
						ram_seq_lock_03 <= 1'b1;
						
//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_03 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_03 + 16'd1450) <= tcp_ack_num_i) & !old_data_en_o)
						ram_lock_r_03 <= 0;						
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_03 + 16'd1450) <= tcp_ack_num_i) & old_data_en_o & (ram_cnt == 6'd3))
						ram_lock_r_03 <= 0;
	else if (start_reg & (ram_cnt == 6'd3))
						ram_lock_r_03 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_03 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd3))
						ram_data_chksum_03 <= udp_data_chksum;

						
assign ram_data_rd_addr_03 = ram_data_rd_addr_r_03 + udp_data_in_rd;
assign ram_data_wr_03 = udp_fifo_data_wr & (ram_cnt == 6'd3);

//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_04;
reg	[ 8:0]	ram_data_rd_addr_r_04;
reg	[31:0]	ram_seq_num_r_04;
reg	[15:0]	ram_data_chksum_04;
reg				ram_lock_r_04;
reg				ram_seq_lock_04;
wire	[ 8:0]	ram_data_rd_addr_04;
wire				ram_data_wr_04;
wire	[31:0]	ram_rdata_04;

ram2048	ram_data_04 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_04	)
	,.wraddress				( ram_data_wr_addr_r_04	)
	,.wren					( ram_data_wr_04			)
	,.q						( ram_rdata_04				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_04 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_04 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_04 <= ram_data_wr_addr_r_04 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_04 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_04 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_04 <= ram_data_rd_addr_r_04 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_04 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_04)) & (ram_cnt == 6'd4))
						ram_seq_num_r_04 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_04 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_04 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_04 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd4))
						ram_seq_lock_04 <= 1'b1;
						
//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_04 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_04 + 16'd1450) <= tcp_ack_num_i)  & !old_data_en_o)
						ram_lock_r_04 <= 0;						
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_04 + 16'd1450) <= tcp_ack_num_i)  & old_data_en_o & (ram_cnt == 6'd4))
						ram_lock_r_04 <= 0;
	else if (start_reg & (ram_cnt == 6'd4))
						ram_lock_r_04 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_04 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd4))
						ram_data_chksum_04 <= udp_data_chksum;

						
assign ram_data_rd_addr_04 = ram_data_rd_addr_r_04 + udp_data_in_rd;
assign ram_data_wr_04 = udp_fifo_data_wr & (ram_cnt == 6'd4);

//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_05;
reg	[ 8:0]	ram_data_rd_addr_r_05;
reg	[31:0]	ram_seq_num_r_05;
reg	[15:0]	ram_data_chksum_05;
reg				ram_lock_r_05;
reg				ram_seq_lock_05;
wire	[ 8:0]	ram_data_rd_addr_05;
wire				ram_data_wr_05;
wire	[31:0]	ram_rdata_05;

ram2048	ram_data_05 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_05	)
	,.wraddress				( ram_data_wr_addr_r_05	)
	,.wren					( ram_data_wr_05			)
	,.q						( ram_rdata_05				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_05 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_05 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_05 <= ram_data_wr_addr_r_05 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_05 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_05 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_05 <= ram_data_rd_addr_r_05 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_05 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_05)) & (ram_cnt == 6'd5))
						ram_seq_num_r_05 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_05 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_05 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_05 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd5))
						ram_seq_lock_05 <= 1'b1;
						
//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_05 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_05 + 16'd1450) <= tcp_ack_num_i) & !old_data_en_o)
						ram_lock_r_05 <= 0;						
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_05 + 16'd1450) <= tcp_ack_num_i) & old_data_en_o & (ram_cnt == 6'd5))
						ram_lock_r_05 <= 0;
	else if (start_reg & (ram_cnt == 6'd5))
						ram_lock_r_05 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_05 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd5))
						ram_data_chksum_05 <= udp_data_chksum;

						
assign ram_data_rd_addr_05 = ram_data_rd_addr_r_05 + udp_data_in_rd;
assign ram_data_wr_05 = udp_fifo_data_wr & (ram_cnt == 6'd5);

//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_06;
reg	[ 8:0]	ram_data_rd_addr_r_06;
reg	[31:0]	ram_seq_num_r_06;
reg	[15:0]	ram_data_chksum_06;
reg				ram_lock_r_06;
reg				ram_seq_lock_06;
wire	[ 8:0]	ram_data_rd_addr_06;
wire				ram_data_wr_06;
wire	[31:0]	ram_rdata_06;

ram2048	ram_data_06 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_06	)
	,.wraddress				( ram_data_wr_addr_r_06	)
	,.wren					( ram_data_wr_06			)
	,.q						( ram_rdata_06				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_06 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_06 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_06 <= ram_data_wr_addr_r_06 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_06 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_06 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_06 <= ram_data_rd_addr_r_06 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_06 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_06)) & (ram_cnt == 6'd6))
						ram_seq_num_r_06 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_06 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_06 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_06 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd6))
						ram_seq_lock_06 <= 1'b1;
						
//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_06 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_06 + 16'd1450) <= tcp_ack_num_i) & !old_data_en_o)
						ram_lock_r_06 <= 0;						
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_06 + 16'd1450) <= tcp_ack_num_i) & old_data_en_o & (ram_cnt == 6'd6))
						ram_lock_r_06 <= 0;
	else if (start_reg & (ram_cnt == 6'd6))
						ram_lock_r_06 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_06 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd6))
						ram_data_chksum_06 <= udp_data_chksum;					

						
assign ram_data_rd_addr_06 = ram_data_rd_addr_r_06 + udp_data_in_rd;
assign ram_data_wr_06 = udp_fifo_data_wr & (ram_cnt == 6'd6);

//---------------------------------------------------------------------
reg	[ 8:0]	ram_data_wr_addr_r_07;
reg	[ 8:0]	ram_data_rd_addr_r_07;
reg	[31:0]	ram_seq_num_r_07;
reg	[15:0]	ram_data_chksum_07;
reg				ram_lock_r_07;
reg				ram_seq_lock_07;
wire	[ 8:0]	ram_data_rd_addr_07;
wire				ram_data_wr_07;
wire	[31:0]	ram_rdata_07;

ram2048	ram_data_07 
(
	.clock 					( pll_62_5m_clk			)
	,.data 					( udp_data_gen				)
	,.rdaddress				( ram_data_rd_addr_07	)
	,.wraddress				( ram_data_wr_addr_r_07	)
	,.wren					( ram_data_wr_07			)
	,.q						( ram_rdata_07				)
);

//RAM WRITE ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_wr_addr_r_07 <= 0;
	else if (udp_eop)
					ram_data_wr_addr_r_07 <= 0;
	else if (udp_fifo_data_wr)
					ram_data_wr_addr_r_07 <= ram_data_wr_addr_r_07 + 1'b1;

//RAM READ ADDRESS
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
					ram_data_rd_addr_r_07 <= 0;
	else if (udp_eop)
					ram_data_rd_addr_r_07 <= 0;
	else if (udp_data_in_rd)
					ram_data_rd_addr_r_07 <= ram_data_rd_addr_r_07 + 1'b1;

//SEQUENCE NUMBER FOR RAM
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_seq_num_r_07 <= 0;
	else if ((start_reg | (old_data_start_o & !ram_seq_lock_07)) & (ram_cnt == 6'd7))
						ram_seq_num_r_07 <= tcp_seq_num_o;
						
//SEQUENCE NUMBER LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)
						ram_seq_lock_07 <= 0;
	else if ((nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_07 + 16'd1450) <= tcp_ack_num_i)) | tcp_ctrl_state_idle)
						ram_seq_lock_07 <= 1'b0;
	else if (start_reg & (ram_cnt == 6'd7))
						ram_seq_lock_07 <= 1'b1;
						
//RAM LOCK
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)	
						ram_lock_r_07 <= 0;
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_07 + 16'd1450) <= tcp_ack_num_i) & !old_data_en_o)
						ram_lock_r_07 <= 0;						
	else if (nl_up_op_end & tcp_flags_i[4] & !tcp_flags_i[2] & ((ram_seq_num_r_07 + 16'd1450) <= tcp_ack_num_i) & old_data_en_o & (ram_cnt == 6'd7))
						ram_lock_r_07 <= 0;
	else if (start_reg & (ram_cnt == 6'd7))
						ram_lock_r_07 <= 1;
						
always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)		ram_data_chksum_07 <= 0;
	else if (udp_run & udp_fifo_data_wr & (ram_cnt == 6'd7))
						ram_data_chksum_07 <= udp_data_chksum;

						
assign ram_data_rd_addr_07 = ram_data_rd_addr_r_07 + udp_data_in_rd;
assign ram_data_wr_07 = udp_fifo_data_wr & (ram_cnt == 6'd7);


//---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


udp_full_transmitter udp_full_transmitter
(
	.clk						(	pll_62_5m_clk	)
	,.rst_n					(	rst_n				)
	
	//control signals
	,.start					(	tcp_start_o | udp_start	| old_data_start )
	
	//output data + controls
	,.data_out				(	udp_data_o		)
	,.be_out					(	udp_be_o			)
	,.data_out_rdy			(	udp_data_rdy_o	)
	,.data_out_rd			(	udp_data_out_rd)
	,.data_in				(	udp_fifo_rdata	)
	,.data_in_rd			(	udp_data_in_rd	)
	,.sop						(	udp_sop			)
	,.eop						(	udp_eop			)
	
	//---------------------------------------------------------------------
	//MAC
	,.mac_src_addr			(	mac_src_addr	)
	,.mac_dst_addr			(	mac_dst_addr	)
	,.mac_type				(	mac_type			)

	//---------------------------------------------------------------------
	//IP
	,.ip_version			(	ip_version		)
	,.ip_head_len			(	ip_head_len		)
	,.ip_dsf					(	ip_dsf			)
	,.ip_total_len			(	ip_total_len	)
	,.ip_id					(	ip_id				)
	,.ip_flag				(	ip_flag			)
	,.ip_frag_offset		(	ip_frag_offset	)
	,.ip_ttl					(	ip_ttl			)
	,.ip_prot				(	ip_prot			)
//	,.ip_head_chksum		(	ip_head_chksum	)
	,.ip_src_addr			(	ip_src_addr		)
	,.ip_dst_addr			(	ip_dst_addr		)
	,.ip_options			(	ip_options		)
	
	//---------------------------------------------------------------------	
	//UDP + TCP
	,.udp_src_port			(	tcp_source_port_o	)
	,.udp_dst_port			(	tcp_dest_port_o	)
	,.udp_data_length		(	tcp_data_len_o		)
	,.tcp_seq_num			(	tcp_seq_num_o	)
	,.tcp_ack_num			(	tcp_ack_num_o	)
	,.tcp_head_len			(	tcp_head_len_o	)
	,.tcp_flags				(	tcp_flags_o		)
	,.tcp_window			(	tcp_window		)
	,.tcp_urgent_ptr		(	tcp_urgent_ptr	)
	,.tcp_options			(	tcp_options		)
	,.udp_data_chksum		(	udp_data_chksum_r)
	
	,.work_o					(	transmitter_work	)
);

wire tcp_controller_busy = udp_run | start_reg | transmitter_work;


//TIMER
reg	[31:0]	timer_reg;
wire				timer_pas;

always @(posedge pll_62_5m_clk or negedge rst_n)
	if (!rst_n)													timer_reg <= 32'd250_000_000;				//0.4
	else if (udp_eop)											timer_reg <= 32'd250_000_000;//32'd10_000;//32'd40_000;//32'd25_000_000;				//0.4
	else if (!timer_pas)										timer_reg <= timer_reg - 1'b1;
	
assign timer_pas = timer_reg == 0;
	
assign fifo4_wr_data_in = {udp_be_o, udp_eop, udp_sop};
assign fifo32_wr_data_in = udp_data_o;
assign fifo4_wr_write = udp_data_rdy_o & !fifo4_wr_full;
assign fifo32_wr_write = udp_data_rdy_o & !fifo32_wr_full;
assign udp_data_out_rd = udp_data_rdy_o & !fifo4_wr_full & !fifo32_wr_full;

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

always @(posedge mac_tx_clk_45_shift or negedge rst_n)
	if (!rst_n)		mac_txd_r <= 8'b0;
	else 				mac_txd_r <= mac_txd;
	
always @(posedge mac_tx_clk_45_shift or negedge rst_n)
	if (!rst_n)		mac_txd_rr <= 8'b0;
	else 				mac_txd_rr <= mac_txd_r;
	
always @(posedge mac_tx_clk_45_shift or negedge rst_n)
	if (!rst_n)		mac_txen_r <= 1'b0;
	else 				mac_txen_r <= mac_txen;

always @(posedge mac_tx_clk_45_shift or negedge rst_n)
	if (!rst_n)		mac_txen_rr <= 1'b0;
	else 				mac_txen_rr <= mac_txen_r;




	
  iobuf4_iobuf_in_u5i iobuf4_h
	 ( 
		.datain		(mac_txd_rr[3:0]),
		.dataout		(iobuf_dat_h)
	 );
	 
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



  iobuf4_iobuf_in_u5i iobuf4_to_phy
	 ( 
		.datain		(rgmii_out4),
		.dataout		(iobuf_dat_to_phy)
	 );
	 
	 
  iobuf1_iobuf_in_r5i iobuf1_to_phy
	 ( 
		.datain		(rgmii_out1),
		.dataout		(iobuf_ctl_to_phy)
	 );


//INOUTS
//-------------------------------------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------------------
reg [3:0] test_reg4;
reg 		 test_reg1;
/*
always @(posedge mac_tx_clk_o)
begin
	test_reg4 <= rgmii_out4;
	test_reg1 <= rgmii_out1;
end
*/


assign rgmii_tx_clk = clk_125;
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
assign out_ctl = iobuf_ctl_to_phy;
assign out_clkd0 = iobuf_dat_to_phy[0];
assign out_clkd1 = iobuf_dat_to_phy[1];
assign out_clkd2 = iobuf_dat_to_phy[2];
assign out_clkd3 = iobuf_dat_to_phy[3];
*/

//ADAPTER OUT
/*
assign out_clk = mac_tx_clk_o;
assign out_ctl = iobuf_ctl_to_phy;
assign out_clkd0 = iobuf_dat_to_phy[0];
assign out_clkd1 = iobuf_dat_to_phy[1];
assign out_clkd2 = iobuf_dat_to_phy[2];
assign out_clkd3 = iobuf_dat_to_phy[3];
*/
endmodule